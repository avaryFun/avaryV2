// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AvaryHouse} from "../src/AvaryHouse.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {PresaleFactory} from "../src/PresaleFactory.sol";

contract DeployBaseTestnet is Script {
    // Base Testnet (Sepolia) Addresses
    address constant UNISWAP_V3_FACTORY = 0x9323c1d6D800ed51Bd7C6B216cfBec678B7d0BC2;
    address constant UNISWAP_V3_POSITION_MANAGER = 0x1B8eef6A5a7D62BD52e8a1640E68b52b4c322c1c;
    address constant UNISWAP_V3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant WRAPPED_ETH = 0x4200000000000000000000000000000000000006;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AvaryHouse
        AvaryHouse avaryHouse = new AvaryHouse(
            address(0), // Will be updated after TokenFactory deployment
            UNISWAP_V3_POSITION_MANAGER,
            deployer, // Set deployer as owner
            UNISWAP_V3_POSITION_MANAGER
        );
        console.log("AvaryHouse deployed to:", address(avaryHouse));

        // 2. Deploy TokenFactory
        TokenFactory tokenFactory = new TokenFactory(
            address(avaryHouse),
            UNISWAP_V3_FACTORY,
            UNISWAP_V3_POSITION_MANAGER,
            UNISWAP_V3_ROUTER,
            deployer, // Set deployer as owner
            WRAPPED_ETH
        );
        console.log("TokenFactory deployed to:", address(tokenFactory));

        // 3. Update AvaryHouse with TokenFactory address
        avaryHouse.updateAvaryFactory(address(tokenFactory));
        console.log("Updated AvaryHouse factory to:", address(tokenFactory));

        // 4. Register default house factory
        bytes32 defaultHouseId = avaryHouse.registerHouseFactory(
            "Default House",
            deployer, // Set deployer as house owner
            deployer, // Set deployer as payout address
            "Default House for Base Testnet"
        );
        console.log("Registered default house with ID:", vm.toString(defaultHouseId));

        // 5. Deploy PresaleFactory
        PresaleFactory presaleFactory = new PresaleFactory(
            address(tokenFactory),
            deployer, // Set deployer as owner
            defaultHouseId
        );
        console.log("PresaleFactory deployed to:", address(presaleFactory));

        // 6. Allow WETH as paired token
        tokenFactory.toggleAllowedPairedToken(WRAPPED_ETH, true);
        console.log("Enabled WETH as paired token");

        vm.stopBroadcast();

        // Final deployment summary
        console.log("\nDeployment Summary:");
        console.log("==================");
        console.log("AvaryHouse:", address(avaryHouse));
        console.log("TokenFactory:", address(tokenFactory));
        console.log("PresaleFactory:", address(presaleFactory));
        console.log("Default House ID:", vm.toString(defaultHouseId));
        console.log("Deployer Address:", deployer);
    }
} 