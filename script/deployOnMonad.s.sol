// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AvaryHouse} from "../src/AvaryHouse.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {PresaleFactory} from "../src/PresaleFactory.sol";

contract DeployOnMonad is Script {
    // Monad Testnet Addresses
    address constant UNISWAP_V3_FACTORY = 0x961235a9020B05C44DF1026D956D1F4D78014276;
    address constant UNISWAP_V3_POSITION_MANAGER = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
    address constant UNISWAP_V3_ROUTER = 0x3aE6D8A282D67893e17AA70ebFFb33EE5aa65893; // Universal Router
    address constant WRAPPED_MON = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701; // Wrapped Monad

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
            WRAPPED_MON // wrappedNative
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
            "Default House for Monad Testnet"
        );
        console.log("Registered default house factory with ID:", vm.toString(defaultHouseId));

        // 5. Deploy PresaleFactory
        PresaleFactory presaleFactory = new PresaleFactory(
            address(tokenFactory), // tokenFactory
            deployer, // owner
            defaultHouseId // defaultHouseFactoryId
        );
        console.log("PresaleFactory deployed to:", address(presaleFactory));

        // 6. Allow WMON as paired token
        tokenFactory.toggleAllowedPairedToken(WRAPPED_MON, true);
        console.log("Enabled WMON as paired token");

        vm.stopBroadcast();
    }
} 