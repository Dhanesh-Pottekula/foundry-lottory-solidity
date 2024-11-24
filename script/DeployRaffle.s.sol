// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffel.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscriptions,Fundsubscription,AddConsumer} from "./interactions.s.sol";

contract DeployRaffle is Script{

function run ()public{}

function deployContract () public returns (Raffle,HelperConfig){
    HelperConfig helperConfig=new HelperConfig();   
    //LOCAL -> deploy mocks and get config
    //sepolia -> get config directly
    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    if (config.subscriptionId ==0){
        CreateSubscriptions createSubcription = new CreateSubscriptions();
        (config.subscriptionId, config.vrfCoordinator) = createSubcription.createSubscription(config.vrfCoordinator,config.account);

        //fund Subscription
        Fundsubscription fundsubscription = new Fundsubscription();
        fundsubscription.fundSubscription(config.vrfCoordinator,config.subscriptionId,config.link,config.account);
    }
    vm.startBroadcast(config.account);
    Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callBackGasLimit
    );
    vm.stopBroadcast();
    AddConsumer addConsumer = new AddConsumer();
    addConsumer.addConsumer(address(raffle),config.vrfCoordinator,config.subscriptionId,config.account);
    return (raffle,helperConfig);
}
}