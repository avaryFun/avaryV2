// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AvaryHouse} from "../src/AvaryHouse.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {PresaleFactory} from "../src/PresaleFactory.sol";

contract DeployOnBase is Script {
    // Base Mainnet Addresses
    address constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant UNISWAP_V3_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant UNISWAP_V3_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    address constant WRAPPED_ETH = 0x4200000000000000000000000000000000000006;

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
            WRAPPED_ETH // wrappedNative
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
            "Default House for Base Mainnet"
        );
        console.log("Registered default house factory with ID:", vm.toString(defaultHouseId));

        // 5. Deploy PresaleFactory
        PresaleFactory presaleFactory = new PresaleFactory(
            address(tokenFactory), // tokenFactory
            deployer, // owner
            defaultHouseId // defaultHouseFactoryId
        );
        console.log("PresaleFactory deployed to:", address(presaleFactory));

        // 6. Allow WETH as paired token
        tokenFactory.toggleAllowedPairedToken(WRAPPED_ETH, true);
        console.log("Enabled WETH as paired token");

        vm.stopBroadcast();
    }
} 