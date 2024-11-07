// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "forge-std/console.sol";

/**
 * @title Raffel
 * @author dhanesh
 * @notice A raffel contract for managing raffel.
 * @dev implements chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**Errors */
    error Raffel__sendMoreToEnterRaffle();
    error Raffel__transeferFailed();
    error Raffel__upKeepNotNedded(uint256 balance, uint256 players, RaffleState state);

    /**Events */
    event RaffelEntered(address indexed player);
    event Winner(address indexed winner);

    /**enums */
    enum RaffleState {OPEN, CALCULATING}

    /**State Variables */
    uint16 private constant REQUESTCONFORMATIONS = 2;
    uint16 private constant NUMBER_OF_WORDS = 2;

    address payable[] public s_players;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    uint256 private immutable i_entryFee;
    /**@dev interval in seconds */
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWInner;
    constructor(
        uint256 _entryfee,
        uint256 _interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 _subcriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = _entryfee;
        i_interval = _interval;

        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = _subcriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        //enter into raffle
        //pays entry fee
        if (msg.value < i_entryFee) {
            revert Raffel__sendMoreToEnterRaffle();
        }
        if(s_raffleState==RaffleState.CALCULATING){
            revert();
        }
        s_players.push(payable(msg.sender));
        emit RaffelEntered(msg.sender);
    }


   /**
    * @dev -check upkeep,, automation function to check if upkeep is needed
    * @param -ignore 
    * @return upkeepNeeded -bool, performData -bytes
    * @return 
    */
     function checkUpkeep(bytes memory /* checkData */)public view
        returns (bool upkeepNeeded, bytes memory /* performData */){
            bool isTimePassed=block.timestamp - s_lastTimeStamp <= i_interval;
            bool isOpen =s_raffleState==RaffleState.OPEN;
            bool hasBalance = address(this).balance > 0;
            bool hasPlayers = s_players.length > 0;
            upkeepNeeded = isTimePassed && isOpen && hasBalance && hasPlayers;
            return (upkeepNeeded, "0x0");
        }

    //get a random number
    function performUpkeep(bytes calldata /* performData */)  public {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffel__upKeepNotNedded(address(this).balance, s_players.length, s_raffleState);
        }
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUESTCONFORMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        // get a random number
    }

    /**Getter functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entryFee;
    }

    function fulfillRandomWords(
        uint256 /**requestId*/, 
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner= randomWords[0] % s_players.length;
        s_recentWInner=s_players[indexOfWinner];
        s_players=new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success,)=s_recentWInner.call{value:address(this).balance}("");

        if (!success){
            revert Raffel__transeferFailed();
        }
        s_raffleState=RaffleState.OPEN;
        emit Winner(s_recentWInner);
    } 

    function getRaffleState () external view returns (RaffleState){
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }
}