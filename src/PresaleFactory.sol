// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AvaryToken} from "./AvaryToken.sol";

interface IPresaleFactory {
    struct PreSalePurchase {
        uint256 bpsBought;
        address user;
    }

    struct PoolConfig {
        int24 tick;
        address pairedToken;
        uint24 devBuyFee;
    }

    struct PreSaleTokenConfig {
        string name;
        string symbol;
        uint256 supply;
        uint24 fee;
        address creator;
        address payout;
        string image;
        bytes32 houseFactoryId;
        PoolConfig poolConfig;
    }

    struct PreSaleConfig {
        uint256 bpsAvailable; // maximum 100%
        uint256 ethPerBps; // how much eth per bps
        uint256 endTime; // when it ends (in epoch seconds)
        uint256 bpsSold; // how many bps have been sold so far
        address tokenAddress; // the deployed token address
    }

    function deployToken(
        PreSaleTokenConfig memory preSaleTokenConfig,
        uint256 preSaleId,
        PreSalePurchase[] memory preSalePurchases,
        PreSaleConfig memory preSaleConfig
    ) external payable returns (address tokenAddress, uint256 positionId);
}

contract PresaleFactory is Ownable, ReentrancyGuard {
    error InvalidConfig();
    error PreSaleNotFound(uint256 preSaleId);
    error PreSaleEnded(uint256 preSaleId);
    error PreSaleNotEnded(uint256 preSaleId);
    error AlreadyRefunded(uint256 preSaleId);
    error InvalidAddress();
    error HouseFactoryNotFound(bytes32 houseFactoryId);

    address public tokenFactory;
    bytes32 public immutable defaultHouseFactoryId;

    string public constant version = "0.0.1";

    mapping(uint256 => IPresaleFactory.PreSaleConfig) public preSaleConfigs;
    mapping(uint256 => IPresaleFactory.PreSaleTokenConfig) public preSaleTokenConfigs;
    mapping(uint256 => IPresaleFactory.PreSalePurchase[]) public preSalePurchases;
    mapping(uint256 => mapping(address => IPresaleFactory.PreSalePurchase[])) public preSalePurchasesForUser;
    mapping(uint256 => bool) public preSaleRefunded;

    event PreSaleCreated(
        uint256 preSaleId,
        uint256 bpsAvailable,
        uint256 ethPerBps,
        uint256 endTime,
        address creator,
        address payout,
        string name,
        string symbol,
        uint256 supply,
        string image,
        bytes32 houseFactoryId
    );

    constructor(
        address tokenFactory_,
        address owner_,
        bytes32 defaultHouseFactoryId_
    ) Ownable(owner_) {
        tokenFactory = tokenFactory_;
        defaultHouseFactoryId = defaultHouseFactoryId_;
    }

    function getPreSalePurchases(
        uint256 preSaleId
    ) external view returns (IPresaleFactory.PreSalePurchase[] memory) {
        return preSalePurchases[preSaleId];
    }

    function getPreSalePurchasesForUser(
        uint256 preSaleId,
        address user
    ) external view returns (IPresaleFactory.PreSalePurchase[] memory) {
        IPresaleFactory.PreSalePurchase[] memory _preSalePurchasesForUser = new IPresaleFactory.PreSalePurchase[](
            preSalePurchasesForUser[preSaleId][user].length
        );
        for (uint256 i = 0; i < preSalePurchasesForUser[preSaleId][user].length; i++) {
            _preSalePurchasesForUser[i] = preSalePurchasesForUser[preSaleId][user][i];
        }
        return _preSalePurchasesForUser;
    }

    function refundPreSale(uint256 preSaleId) external nonReentrant {
        if (preSaleRefunded[preSaleId]) revert AlreadyRefunded(preSaleId);
        IPresaleFactory.PreSaleConfig memory preSaleConfig = preSaleConfigs[preSaleId];

        if (preSaleConfig.bpsAvailable == 0) revert PreSaleNotFound(preSaleId);

        // Must be after the period and only if not sold out
        if (preSaleConfig.bpsSold >= preSaleConfig.bpsAvailable)
            revert PreSaleEnded(preSaleId);

        if (block.timestamp < preSaleConfig.endTime)
            revert PreSaleNotEnded(preSaleId);

        for (uint256 i = 0; i < preSalePurchases[preSaleId].length; i++) {
            IPresaleFactory.PreSalePurchase memory purchase = preSalePurchases[preSaleId][i];
            // Refund user
            payable(purchase.user).transfer(
                (preSaleConfig.ethPerBps * purchase.bpsBought)
            );
        }

        preSaleRefunded[preSaleId] = true;
    }

    function buyIntoPreSale(uint256 preSaleId) external payable nonReentrant {
        IPresaleFactory.PreSaleConfig memory preSaleConfig = preSaleConfigs[preSaleId];

        if (preSaleConfig.bpsAvailable == 0) revert PreSaleNotFound(preSaleId);
        if (block.timestamp > preSaleConfig.endTime)
            revert PreSaleEnded(preSaleId);
        if (preSaleConfig.bpsSold >= preSaleConfig.bpsAvailable)
            revert PreSaleEnded(preSaleId);

        uint256 bpsToBuy = msg.value / preSaleConfig.ethPerBps;
        uint256 bpsRemaining = preSaleConfig.bpsAvailable - preSaleConfig.bpsSold;

        uint256 ethSpent;

        if (bpsToBuy > bpsRemaining) {
            bpsToBuy = bpsRemaining;
            ethSpent = bpsRemaining * preSaleConfig.ethPerBps;
        } else {
            ethSpent = bpsToBuy * preSaleConfig.ethPerBps;
        }

        uint256 ethRefund = msg.value - ethSpent;

        preSaleConfig.bpsSold += bpsToBuy;
        preSaleConfigs[preSaleId] = preSaleConfig;

        preSalePurchases[preSaleId].push(
            IPresaleFactory.PreSalePurchase({
                bpsBought: bpsToBuy,
                user: msg.sender
            })
        );

        preSalePurchasesForUser[preSaleId][msg.sender].push(
            IPresaleFactory.PreSalePurchase({
                bpsBought: bpsToBuy,
                user: msg.sender
            })
        );

        if (ethRefund > 0) {
            payable(msg.sender).transfer(ethRefund);
        }

        // If the pre sale is sold out, deploy the token
        if (preSaleConfig.bpsSold >= preSaleConfig.bpsAvailable) {
            IPresaleFactory.PreSaleTokenConfig memory preSaleTokenConfig = preSaleTokenConfigs[preSaleId];
            IPresaleFactory.PreSalePurchase[] memory preSalePurchasesForDeploy = preSalePurchases[preSaleId];
            IPresaleFactory.PreSaleConfig memory preSaleConfigForDeploy = preSaleConfigs[preSaleId];

            preSaleConfigForDeploy.bpsSold = preSaleConfig.bpsSold;
            (address tokenAddress, ) = IPresaleFactory(tokenFactory).deployToken{
                value: preSaleConfig.bpsSold * preSaleConfig.ethPerBps
            }(
                preSaleTokenConfig,
                preSaleId,
                preSalePurchasesForDeploy,
                preSaleConfigForDeploy
            );

            preSaleConfigForDeploy.tokenAddress = tokenAddress;
            preSaleConfigs[preSaleId] = preSaleConfigForDeploy;
        }
    }

    function createPreSaleToken(
        IPresaleFactory.PreSaleConfig memory _preSaleConfig,
        uint256 _preSaleId,
        IPresaleFactory.PreSaleTokenConfig memory _preSaleTokenConfig
    ) external {
        IPresaleFactory.PreSaleConfig memory preSaleConfig = preSaleConfigs[_preSaleId];

        if (_preSaleId == 0) revert InvalidConfig();
        if (preSaleConfig.bpsAvailable != 0) revert InvalidConfig();
        if (_preSaleConfig.bpsAvailable >= 10000) revert InvalidConfig();
        if (_preSaleTokenConfig.creator == address(0) || _preSaleTokenConfig.payout == address(0)) 
            revert InvalidAddress();

        // Use default house factory if not specified
        if (_preSaleTokenConfig.houseFactoryId == bytes32(0)) {
            _preSaleTokenConfig.houseFactoryId = defaultHouseFactoryId;
        }

        preSaleConfigs[_preSaleId] = _preSaleConfig;
        preSaleTokenConfigs[_preSaleId] = _preSaleTokenConfig;

        emit PreSaleCreated(
            _preSaleId,
            _preSaleConfig.bpsAvailable,
            _preSaleConfig.ethPerBps,
            _preSaleConfig.endTime,
            _preSaleTokenConfig.creator,
            _preSaleTokenConfig.payout,
            _preSaleTokenConfig.name,
            _preSaleTokenConfig.symbol,
            _preSaleTokenConfig.supply,
            _preSaleTokenConfig.image,
            _preSaleTokenConfig.houseFactoryId
        );
    }

    /**
     * @notice Withdraws ETH from the contract to the specified address (emergencies only)
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        payable(to).transfer(amount);
    }

    function setTokenFactory(address _tokenFactory) external onlyOwner {
        tokenFactory = _tokenFactory;
    }
}
