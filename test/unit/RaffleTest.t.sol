// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffel.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    /**
     * Events
     */
    event RaffelEntered(address indexed player);
    event Winner(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callBackGasLimit;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callBackGasLimit = config.callBackGasLimit;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughMoneyPaid() public {
        //Arrange
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffel__sendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
        //act

        //assert
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();

        //asset
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        //act
        vm.expectEmit(true, false, false, false, address(raffle)); // expects an event to be emitted
        emit RaffelEntered(PLAYER); // this is the exact event that should be emitted

        //assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileCalculating() public raffelEntered {
        raffle.performUpkeep("");

        //act
        vm.expectRevert(Raffle.Raffle__RaffleCalculating.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //assert
    }

    function testCheckUpkeepReturnsFalseIItHasNoBalance() public {
        //arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleStatusIsNotOpen() public raffelEntered {
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIftimeNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAllGood() public raffelEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded);
    }

    ///////////////// PERFORM UPKEEP//////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public raffelEntered {
        //act
        raffle.performUpkeep("");
    }

    modifier raffelEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != ETH_LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitReqeustId() public raffelEntered {
        //act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        //assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    function testFullFillRandonWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 requestId)
        public
        raffelEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetAndSendMoney() public raffelEntered skipFork {
        uint256 additionalEntrants = 3; //total 4 participants
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 winnerStartingBalance = expectedWinner.balance;
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerbalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 price = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerbalance == winnerStartingBalance + price);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
