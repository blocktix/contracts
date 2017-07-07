pragma solidity ^0.4.11;


import 'zeppelin-solidity/contracts/token/StandardToken.sol';


/**
 * @title Blocktix Token Generation Event contract
 *
 * @dev Based on code by BAT: https://github.com/brave-intl/basic-attention-token-crowdsale/blob/master/contracts/BAToken.sol
 */
contract TIXGeneration is StandardToken {
    string public constant name = "Blocktix Token";
    string public constant symbol = "TIX";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // crowdsale parameters
    bool public isFinalized;              // switched to true in operational state
    uint256 public startTime = 0;         // crowdsale start time (in seconds)
    uint256 public endTime = 0;           // crowdsale end time (in seconds)
    uint256 public constant tokenGenerationCap =  62.5 * (10**6) * 10**decimals; // 62.5m TIX
    uint256 public constant t2tokenExchangeRate = 1250;
    uint256 public constant t3tokenExchangeRate = 1041;
    uint256 public constant tixFund = tokenGenerationCap / 100 * 24;     // 24%
    uint256 public constant tixFounders = tokenGenerationCap / 100 * 10; // 10%
    uint256 public constant tixPromo = tokenGenerationCap / 100 * 2;     // 2%
    uint256 public constant tixPresale = 29.16 * (10**6) * 10**decimals;    // 29.16m TIX Presale

    uint256 public constant finalTier = 52.5 * (10**6) * 10**decimals; // last 10m
    uint256 public tokenExchangeRate = t2tokenExchangeRate;

    // addresses
    address public ethFundDeposit;      // deposit address for ETH for Blocktix
    address public tixFundDeposit;      // deposit address for TIX for Blocktix
    address public tixFoundersDeposit;  // deposit address for TIX for Founders
    address public tixPromoDeposit;     // deposit address for TIX for Promotion
    address public tixPresaleDeposit;   // deposit address for TIX for Presale

    /**
    * @dev modifier to allow actions only when the contract IS finalized
    */
    modifier whenFinalized() {
        if (!isFinalized) throw;
        _;
    }

    /**
    * @dev modifier to allow actions only when the contract IS NOT finalized
    */
    modifier whenNotFinalized() {
        if (isFinalized) throw;
        _;
    }

    // ensures that the current time is between _startTime (inclusive) and _endTime (exclusive)
    modifier between(uint256 _startTime, uint256 _endTime) {
        assert(now >= _startTime && now < _endTime);
        _;
    }

    // verifies that an amount is greater than zero
    modifier validAmount() {
        require(msg.value > 0);
        _;
    }

    // validates an address - currently only checks that it isn't null
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    // events
    event CreateTIX(address indexed _to, uint256 _value);

    /**
    * @dev Contructor that assigns all presale tokens and starts the sale
    */
    function TIXGeneration(
        address _ethFundDeposit,
        address _tixFundDeposit,
        address _tixFoundersDeposit,
        address _tixPromoDeposit,
        address _tixPresaleDeposit,
        uint256 _startTime,
        uint256 _endTime)
    {
        isFinalized = false; // Initialize presale

        ethFundDeposit = _ethFundDeposit;
        tixFundDeposit = _tixFundDeposit;
        tixFoundersDeposit = _tixFoundersDeposit;
        tixPromoDeposit = _tixPromoDeposit;
        tixPresaleDeposit = _tixPresaleDeposit;

        startTime = _startTime;
        endTime = _endTime;

        // Allocate presale and founders tix
        totalSupply = tixFund;
        totalSupply += tixFounders;
        totalSupply += tixPromo;
        totalSupply += tixPresale;
        balances[tixFundDeposit] = tixFund;         // Deposit TIX for Blocktix
        balances[tixFoundersDeposit] = tixFounders; // Deposit TIX for Founders
        balances[tixPromoDeposit] = tixPromo;       // Deposit TIX for Promotion
        balances[tixPresaleDeposit] = tixPresale;   // Deposit TIX for Presale
        CreateTIX(tixFundDeposit, tixFund);         // logs TIX for Blocktix
        CreateTIX(tixFoundersDeposit, tixFounders); // logs TIX for Founders
        CreateTIX(tixPromoDeposit, tixPromo);       // logs TIX for Promotion
        CreateTIX(tixPresaleDeposit, tixPresale);   // logs TIX for Presale

    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    *
    * can only be called during once the the funding period has been finalized
    */
    function transfer(address _to, uint _value) whenFinalized {
        super.transfer(_to, _value);
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amout of tokens to be transfered
    *
    * can only be called during once the the funding period has been finalized
    */
    function transferFrom(address _from, address _to, uint _value) whenFinalized {
        super.transferFrom(_from, _to, _value);
    }

    /**
     * @dev Accepts ETH and generates TIX tokens
     *
     * can only be called during the crowdsale
     */
    function generateTokens()
        public
        payable
        whenNotFinalized
        between(startTime, endTime)
        validAmount
    {
        if (totalSupply == tokenGenerationCap)
            throw;

        uint256 tokens = SafeMath.mul(msg.value, tokenExchangeRate); // check that we're not over totals
        uint256 checkedSupply = SafeMath.add(totalSupply, tokens);
        uint256 diff;

        // switch to next tier
        if (tokenExchangeRate != t3tokenExchangeRate && finalTier < checkedSupply)
        {
            diff = SafeMath.sub(checkedSupply, finalTier);
            tokens = SafeMath.sub(tokens, diff);
            uint256 ethdiff = SafeMath.div(diff, t2tokenExchangeRate);
            tokenExchangeRate = t3tokenExchangeRate;
            tokens = SafeMath.add(tokens, SafeMath.mul(ethdiff, tokenExchangeRate));
            checkedSupply = SafeMath.add(totalSupply, tokens);
        }

        // return money if something goes wrong
        if (tokenGenerationCap < checkedSupply)
        {
            diff = SafeMath.sub(checkedSupply, tokenGenerationCap);
            if (diff > 10**12)
                throw;
            checkedSupply = SafeMath.sub(checkedSupply, diff);
            tokens = SafeMath.sub(tokens, diff);
        }

        totalSupply = checkedSupply;
        balances[msg.sender] += tokens;
        CreateTIX(msg.sender, tokens); // logs token creation
    }

    /**
    * @dev Ends the funding period and sends the ETH home
    */
    function finalize()
        external
        whenNotFinalized
    {
        if (msg.sender != ethFundDeposit) throw; // locks finalize to the ultimate ETH owner
        if (now <= endTime && totalSupply != tokenGenerationCap) throw;
        // move to operational
        isFinalized = true;
        if(!ethFundDeposit.send(this.balance)) throw;  // send the eth to Blocktix
    }

    // fallback
    function()
        payable
        whenNotFinalized
    {
        generateTokens();
    }
}

