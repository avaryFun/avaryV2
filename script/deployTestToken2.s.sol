// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {AvaryToken} from "../src/AvaryToken.sol";

contract DeployTestToken2 is Script {
    // Base Mainnet Addresses - Using the addresses from the previous deployment
    address constant TOKEN_FACTORY = 0x3A0E19d0f764BC8BE70dE69507DE6e2b9373ac21; // TokenFactory address on Base
    
    // Using USDC on Base instead of WETH since it has a higher address
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
    bytes32 constant DEFAULT_HOUSE_ID = 0x124656a67e69a937decf427e950fca776f3a53676e91aa7612fd6c0f1d8b76b7; // Default House Factory ID

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Token configuration
        string memory name = "TEST2 Token";
        string memory symbol = "TEST2";
        uint256 supply = 100_000_000 * 10**18; // 100 million tokens with 18 decimals
        uint24 fee = 3000; // 0.3% fee tier
        string memory image = "https://example.com/test-token.png"; // Token image URL
        
        // Pool configuration with USDC and new tick value
        TokenFactory.PoolConfig memory poolConfig = TokenFactory.PoolConfig({
            tick: -107820, // New tick value as requested
            pairedToken: USDC, // Using USDC as the paired token
            devBuyFee: 3000 // 0.3% fee for dev buys
        });

        console.log("Deploying token with name:", name);
        console.log("Deploying token with symbol:", symbol);
        console.log("Deployer address:", deployer);
        console.log("Using tick value:", -107820);
        
        // Deploy token
        TokenFactory factory = TokenFactory(TOKEN_FACTORY);
        
        try factory.deployToken(
            name,
            symbol,
            supply,
            fee,
            deployer, // creator
            deployer, // payout
            image,
            poolConfig,
            DEFAULT_HOUSE_ID
        ) returns (AvaryToken token, uint256 positionId) {
            console.log("Token deployed at:", address(token));
            console.log("Position ID:", positionId);
            console.log("Token name:", token.name());
            console.log("Token symbol:", token.symbol());
            console.log("Token creator:", token.creator());
            console.log("Token payout:", token.payout());
        } catch Error(string memory reason) {
            console.log("Deployment failed with reason:", reason);
        } catch (bytes memory) {
            console.log("Deployment failed with unknown error");
        }

        vm.stopBroadcast();
    }
} 