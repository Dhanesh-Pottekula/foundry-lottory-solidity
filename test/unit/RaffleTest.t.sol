// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffel.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import "forge-std/console.sol";
contract RaffleTest is Test {
        /**Events */
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
 address public PLAYER =makeAddr('player');
 uint256 public constant STARTING_PLAYER_BALANCE=10 ether;

    function setUp () external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig)= deployer.deployContract(); 
        HelperConfig.NetworkConfig memory config=helperConfig.getConfig();
        entranceFee=config.entranceFee;
        interval = config.interval;
        vrfCoordinator=config.vrfCoordinator;
        gasLane=config.gasLane;
        subscriptionId=config.subscriptionId;
        callBackGasLimit=config.callBackGasLimit;
        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState()== Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughMoneyPaid () public {
        //Arrange
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffel__sendMoreToEnterRaffle.selector);
        raffle.enterRaffle ();
        //act

        //assert
    }

    function testRaffleRecordsPlayersWhenTheyEnter ()public{
        //arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value:entranceFee}();

        //asset
        address playerRecorded =raffle.getPlayer(0);
        assert (playerRecorded==PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public{
        vm.prank(PLAYER);
        //act 
        vm.expectEmit(true,false,false,false,address(raffle));// expects an event to be emitted
        emit RaffelEntered(PLAYER);// this is the exact event that should be emitted 

        //assert 
        raffle.enterRaffle{value:entranceFee}();
    }
    function testDontAllowPlayersToEnterWhileCalculating() public{
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp +interval+1);
        vm.roll(block.number +1);
        raffle.performUpkeep('');

        //act
        vm.expectRevert(Raffle.Raffle__RaffleCalculating.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        //assert
    }
}