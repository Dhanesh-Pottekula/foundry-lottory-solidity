// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {HelperConfig,CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffel.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
contract CreateSubscriptions is Script{

function createSubscriptionUsingConfig()public returns (uint256, address){
    HelperConfig helperConfig=new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
   return  createSubscription(vrfCoordinator);
}
function run () public{

}
function createSubscription(address vrfCoordinator)public returns (uint256, address){
vm.startBroadcast();
uint256 subId=VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
vm.stopBroadcast();
console.log('this is your sub id up date your config ',subId);
return (subId,vrfCoordinator);
}

}

contract Fundsubscription is Script,CodeConstants {
    uint96 public constant FUND_AMOUNT = 3 ether;
    function fundSubscriptionUsingConfig() public{
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address linkToken = helperConfig.getConfig().link;
    fundSubscription (vrfCoordinator,subscriptionId,linkToken);
    }
    
    function fundSubscription(address vrfCoordinator,uint256 subscriptionId,address linkToken) public{
    if(block.chainid==ETH_LOCAL_CHAIN_ID){
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId,FUND_AMOUNT);
    vm.stopBroadcast();
    }else {
    vm.startBroadcast();
    LinkToken(linkToken).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subscriptionId));
    }
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinator;
        // address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

