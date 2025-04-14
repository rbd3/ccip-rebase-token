//SPDX-License-Idendifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IRebaseToken} from "src/Interfaces/IRebaseToken.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {RebaseTokenPool} from "src/TokenPool.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RegistryModuleOwnerCustom} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink/local/src/ccip/Register.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/ERC20.sol";

contract CrossChain is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    address owner = makeAddr("owner");

    CCIPLocalSimulatorFork ccipSimulatorFork;
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipSimulatorFork = new CCIPLocalSimulatorFork();

        vm.makePersistent(address(ccipSimulatorFork));

        // 1. Deploy and configure on sepolia
        sepoliaNetworkDetails = ccipSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        sepoliaToken.mintAndBurnRole(address(vault));
        sepoliaToken.mintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(sepoliaToken));

        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // 2. Deploy and configure on arbSepolia
        arbSepoliaNetworkDetails = ccipSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner);
        vm.selectFork(arbSepoliaFork);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        arbSepoliaToken.mintAndBurnRole(address(vault));
        arbSepoliaToken.mintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));

        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));

        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );

        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        //          struct ChainUpdate {
        //                 uint64 remoteChainSelector; // ──╮ Remote chain selector
        //                 bool allowed; // ────────────────╯ Whether the chain should be enabled
        //                 bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //                 bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //                 RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //                 RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }
        vm.selectFork(fork);
        vm.prank(owner);
        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }
}
