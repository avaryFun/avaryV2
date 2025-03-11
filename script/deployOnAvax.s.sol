// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AvaryHouse} from "../src/AvaryHouse.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {PresaleFactory} from "../src/PresaleFactory.sol";

contract DeployOnAvax is Script {
    // Avalanche C-Chain Addresses
    address constant UNISWAP_V3_FACTORY = 0x740b1c1de25031C31FF4fC9A62f554A55cdC1baD;
    address constant UNISWAP_V3_POSITION_MANAGER = 0x655C406EBFa14EE2006250925e54ec43AD184f8B;
    address constant UNISWAP_V3_ROUTER = 0x4Dae2f939ACf50408e13d58534Ff8c2776d45265; // Universal Router
    address constant WRAPPED_AVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // Wrapped AVAX

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AvaryHouse first with tokenFactory as address(0)
        AvaryHouse avaryHouse = new AvaryHouse(
            address(0), // TokenFactory will be set later
            UNISWAP_V3_POSITION_MANAGER, // token
            deployer, // owner
            UNISWAP_V3_POSITION_MANAGER // positionManager
        );
        console.log("AvaryHouse deployed to:", address(avaryHouse));

        // 2. Deploy TokenFactory with AvaryHouse address
        TokenFactory tokenFactory = new TokenFactory(
            address(avaryHouse), // locker
            UNISWAP_V3_FACTORY, // uniswapV3Factory
            UNISWAP_V3_POSITION_MANAGER, // positionManager
            UNISWAP_V3_ROUTER, // swapRouter
            deployer, // owner
            WRAPPED_AVAX // wrappedNative
        );
        console.log("TokenFactory deployed to:", address(tokenFactory));

        // 3. Update AvaryHouse with TokenFactory address
        avaryHouse.updateAvaryFactory(address(tokenFactory));
        console.log("Updated AvaryHouse with TokenFactory address");

        // 4. Register default house factory
        bytes32 defaultHouseId = avaryHouse.registerHouseFactory(
            "Default House",
            deployer,
            deployer,
            "Default House for Avalanche C-Chain"
        );
        console.log("Registered default house factory with ID:", vm.toString(defaultHouseId));

        // 5. Deploy PresaleFactory
        PresaleFactory presaleFactory = new PresaleFactory(
            address(tokenFactory), // tokenFactory
            deployer, // owner
            defaultHouseId // defaultHouseFactoryId
        );
        console.log("PresaleFactory deployed to:", address(presaleFactory));

        // 6. Allow WAVAX as paired token
        tokenFactory.toggleAllowedPairedToken(WRAPPED_AVAX, true);
        console.log("Enabled WAVAX as paired token");

        vm.stopBroadcast();
    }
} 