//SPDX-License-Idendifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IRebaseToken} from "src/Interfaces/IRebaseToken.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {RebaseTokenPool} from "src/TokenPool.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChain is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    address constant owner = makeAddr("owner");

    CCIPLocalSimulatorFork ccipSimulatorFork;
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipSimulatorFork = new CCIPLocalSimulatorFork();

        vm.makePersistent(address(ccipSimulatorFork));

        // 1. Deploy and configure on sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(sepoliaToken));

        vm.stopPrank();

        // 2. Deploy and configure on arbSepolia
        vm.startPrank(owner);
        vm.selectFork(arbSepoliaFork);
        arbSepoliaToken = new RebaseToken();

        vm.stopPrank();
    }
}
