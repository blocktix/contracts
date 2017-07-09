pragma solidity ^0.4.11;


import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import './TIXStalledToken.sol';


/**
 * @title Blocktix Token Generation Event contract
 *
 * @dev Based on code by BAT: https://github.com/brave-intl/basic-attention-token-crowdsale/blob/master/contracts/BAToken.sol
 */
contract TIXToken is StandardToken {
    mapping(address => bool) converted; // Converting from old token contract

    string public constant name = "Blocktix Token";
    string public constant symbol = "TIX";
    uint256 public constant decimals = 18;
    string public version = "1.0.1";

    // crowdsale parameters
    bool public isFinalized;                      // switched to true in operational state
    uint256 public startTime = 1501271999;        // crowdsale start time (in seconds) - this will be set once the conversion is done
    uint256 public constant endTime = 1501271999; // crowdsale end time (in seconds)
    uint256 public constant tokenGenerationCap =  62.5 * (10**6) * 10**decimals; // 62.5m TIX
    uint256 public constant tokenExchangeRate = 1041;

    // addresses
    address public tixGenerationContract; // contract address for TIX v1 Funding
    address public ethFundDeposit;        // deposit address for ETH for Blocktix

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
    function TIXToken(address _tixGenerationContract)
    {
        isFinalized = false; // Initialize presale
        tixGenerationContract = _tixGenerationContract;
        ethFundDeposit = TIXStalledToken(tixGenerationContract).ethFundDeposit();
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

        // return if something goes wrong
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

    function hasConverted(address who) constant returns (bool)
    {
      return converted[who];
    }

    function convert(address _owner)
        external
    {
        TIXStalledToken tixStalled = TIXStalledToken(tixGenerationContract);
        if (tixStalled.isFinalized()) throw; // We can't convert tokens after the contract is finalized
        if (converted[_owner]) throw; // Throw if they have already converted
        uint256 balanceOf = tixStalled.balanceOf(_owner);
        if (balanceOf <= 0) throw; // Throw if they don't have an existing balance
        converted[_owner] = true;
        totalSupply += balanceOf;
        balances[_owner] += balanceOf;
        Transfer(this, _owner, balanceOf);
    }

    function continueGeneration()
        external
    {
        TIXStalledToken tixStalled = TIXStalledToken(tixGenerationContract);
        // Allow the sale to continue
        if (totalSupply == tixStalled.totalSupply() && tixStalled.isFinalized())
          startTime = now;
        else
          throw;
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

