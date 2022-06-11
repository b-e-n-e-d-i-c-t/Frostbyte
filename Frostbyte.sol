// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';

contract ATestnetConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 private constant ORACLE_PAYMENT = 1 * LINK_DIVISIBILITY; // 1 * 10**18

    //Humidity and Temperature
    //Bounds act as the threshold values determined by person
    //Who is looking to be insured

    uint256 public humidity;
    uint256 public temperature;
    uint256 public tempBound;
    uint256 public humBound;

    //Duration for how long they want the contract to be
    uint256 public duration;

    //Time of when the contract was insured
    //The contract begins once the person has been insured.
    uint256 public startContract;

    //Initial amount deposited by person
    uint256 public bond;

    //Insured Person who created contract
    address payable public admin;

    //The insurer of the person
    address payable public insurer;
    bool public insured;

    event RequestTemperatureFulfilled(bytes32 indexed requestId, uint256 indexed temp);

    event RequestHumidityFulfilled(bytes32 indexed requestId, uint256 indexed hum);


    /**
     *  KOVAN
     *@dev LINK address in Kovan network: 0xa36085F69e2889c224210F603D836748e7dC0088
     * @dev Check https://docs.chain.link/docs/link-token-contracts/ for LINK address for the right network
     */

    //Contract Constructor input variables are the desired thresholds
    //of both the humidity and temperature, and also the duration
    //of the contract (how long they want to be insured for)
    constructor(uint256 _tempBound,
     uint256 _humBound,
        uint256 _duration) ConfirmedOwner(msg.sender) payable {
        require(_humBound >= 0 && _tempBound >= 0 && _duration >= 120 && _humBound <=100 );
        setChainlinkToken(0xa36085F69e2889c224210F603D836748e7dC0088);
        tempBound = _tempBound;
        humBound = _humBound;
        duration = _duration;
        admin = payable(msg.sender);
        bond = msg.value;
    }

    //Request Oracle to fetch the temperature
    function requestTemperature(address _oracle, string memory _jobId) private {
        Chainlink.Request memory req = buildChainlinkRequest(
            stringToBytes32(_jobId),
            address(this),
            this.fulfillTemperature.selector
        );
        req.add('get', 'https://api.thingspeak.com/channels/1683058/feeds.json?results=1');
        req.add('path', 'feeds,0,field3');
        sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT);
    }

    //Request Humidity from oracle
    function requestHumidity(address _oracle, string memory _jobId) private {
        Chainlink.Request memory req = buildChainlinkRequest(
            stringToBytes32(_jobId),
            address(this),
            this.fulfillHumidity.selector
        );
        req.add('get', 'https://api.thingspeak.com/channels/1683058/feeds.json?results=1');
        req.add('path', 'feeds,0,field4');
        sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT);
    }

    function requestDHT(address _oracle, string memory _jobId) public {
        require (block.timestamp > (duration + startContract));
        requestTemperature(_oracle, _jobId);
        requestHumidity(_oracle, _jobId);
    }

    //Payout function, first requires that the contractual duration has elapsed.
    function payout() public payable {
        require(block.timestamp > (duration + startContract), 'Contract duration still active.');
        if (temperature > tempBound ||
            humidity > humBound
            ){
                //Temp or Hum exeeded agreement
                //Pays out insurance to person
                admin.transfer(address(this).balance);
                
            }
        else{

            //Temp or Hum stayed within range
            //Payout to insurer
            insurer.transfer(address(this).balance);

        }
    }

    function insure() public payable {
        //Require that the insurer puts down double the stake of the person
        require(msg.value > bond);
        insurer = payable(msg.sender);
        startContract = block.timestamp;
        insured = true;
    }

    function fulfillTemperature(bytes32 _requestId, uint256 _temperature) public recordChainlinkFulfillment(_requestId) {
        emit RequestTemperatureFulfilled(_requestId, _temperature);
        temperature = _temperature;
    }

    function fulfillHumidity(bytes32 _requestId, uint256 _humidity) public recordChainlinkFulfillment(_requestId) {
        emit RequestTemperatureFulfilled(_requestId, _humidity);
        humidity = _humidity;
    }

    function showbalance() public view returns (uint){
        return address(this).balance;
    }

    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
}
