// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TickMath} from "./TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INonfungiblePositionManager, IUniswapV3Factory, ILocker, ISwapRouter, ExactInputSingleParams} from "./interface.sol";
import {AvaryToken} from "./AvaryToken.sol";
import {AvaryHouse} from "./AvaryHouse.sol";

contract TokenFactory is Ownable {
    using TickMath for int24;

    error Deprecated();
    error InvalidConfig();
    error NotAllowedPairedToken(address token);
    error TokenNotFound(address token);
    error InvalidAddress();
    error InvalidTickSpacing();
    error HouseFactoryNotFound(bytes32 houseFactoryId);

    AvaryHouse public liquidityLocker;
    string public constant version = "0.0.2";

    address public immutable wrappedNative;

    IUniswapV3Factory public uniswapV3Factory;
    INonfungiblePositionManager public positionManager;
    address public swapRouter;

    bool public deprecated;

    mapping(address => bool) public allowedPairedTokens;

    struct PoolConfig {
        int24 tick;
        address pairedToken;
        uint24 devBuyFee;
    }

    struct DeploymentInfo {
        address token;
        uint256 positionId;
        address locker;
        address creator;
        address payout;
        bytes32 houseFactoryId;
    }

    mapping(address => DeploymentInfo[]) public tokensDeployedByUsers;
    mapping(address => DeploymentInfo) public deploymentInfoForToken;

    event TokenCreated(
        address tokenAddress,
        uint256 positionId,
        address creator,
        address payout,
        string name,
        string symbol,
        uint256 supply,
        address lockerAddress,
        bytes32 houseFactoryId
    );

    constructor(
        address locker_,
        address uniswapV3Factory_,
        address positionManager_,
        address swapRouter_,
        address owner_,
        address wrappedNative_
    ) Ownable(owner_) {
        liquidityLocker = AvaryHouse(locker_);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        positionManager = INonfungiblePositionManager(positionManager_);
        swapRouter = swapRouter_;
        wrappedNative = wrappedNative_;
    }

    function getTokensDeployedByUser(
        address user
    ) external view returns (DeploymentInfo[] memory) {
        return tokensDeployedByUsers[user];
    }

    function configurePool(
        address newToken,
        address pairedToken,
        int24 tick,
        int24 tickSpacing,
        uint24 fee,
        uint256 supplyPerPool,
        address deployer,
        bytes32 houseFactoryId
    ) internal returns (uint256 positionId) {
        require(newToken < pairedToken, "Invalid token order");

        uint160 sqrtPriceX96 = tick.getSqrtRatioAtTick();

        // Create pool
        address pool = uniswapV3Factory.createPool(newToken, pairedToken, fee);

        // Initialize pool
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                newToken,
                pairedToken,
                fee,
                tick,
                maxUsableTick(tickSpacing),
                supplyPerPool,
                0,
                0,
                0,
                address(this),
                block.timestamp
            );
        (positionId, , , ) = positionManager.mint(params);

        positionManager.safeTransferFrom(
            address(this),
            address(liquidityLocker),
            positionId
        );

        liquidityLocker.addUserRewardRecipient(
            AvaryHouse.UserRewardRecipient({
                recipient: deployer,
                lpTokenId: positionId,
                houseFactoryId: houseFactoryId
            })
        );
    }

    function deployToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _supply,
        uint24 _fee,
        address _creator,
        address _payout,
        string memory _image,
        PoolConfig memory _poolConfig,
        bytes32 _houseFactoryId
    )
        external
        payable
        returns (AvaryToken token, uint256 positionId)
    {
        if (deprecated) revert Deprecated();
        if (!allowedPairedTokens[_poolConfig.pairedToken])
            revert NotAllowedPairedToken(_poolConfig.pairedToken);

        // Validate addresses
        if (_creator == address(0) || _payout == address(0)) revert InvalidAddress();
        
        // Validate tick spacing
        int24 tickSpacing = uniswapV3Factory.feeAmountTickSpacing(_fee);
        if (tickSpacing == 0 || _poolConfig.tick % tickSpacing != 0) 
            revert InvalidTickSpacing();

        token = new AvaryToken(
            _name,
            _symbol,
            _supply,
            _creator,
            _payout,
            _image,
            _houseFactoryId
        );

        token.approve(address(positionManager), _supply);

        positionId = configurePool(
            address(token),
            _poolConfig.pairedToken,
            _poolConfig.tick,
            tickSpacing,
            _fee,
            _supply,
            _payout,
            _houseFactoryId
        );

        if (msg.value > 0) {
            uint256 amountOut = msg.value;
            if (_poolConfig.pairedToken != wrappedNative) {
                ExactInputSingleParams memory swapParams = ExactInputSingleParams({
                    tokenIn: wrappedNative,
                    tokenOut: _poolConfig.pairedToken,
                    fee: _poolConfig.devBuyFee,
                    recipient: address(this),
                    amountIn: msg.value,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

                amountOut = ISwapRouter(swapRouter).exactInputSingle{
                    value: msg.value
                }(swapParams);

                IERC20(_poolConfig.pairedToken).approve(
                    address(swapRouter),
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                );
            }

            ExactInputSingleParams memory swapParamsToken = ExactInputSingleParams({
                tokenIn: _poolConfig.pairedToken,
                tokenOut: address(token),
                fee: _fee,
                recipient: _payout,
                amountIn: amountOut,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            ISwapRouter(swapRouter).exactInputSingle{
                value: _poolConfig.pairedToken == wrappedNative ? msg.value : 0
            }(swapParamsToken);
        }

        DeploymentInfo memory deploymentInfo = DeploymentInfo({
            token: address(token),
            positionId: positionId,
            locker: address(liquidityLocker),
            creator: _creator,
            payout: _payout,
            houseFactoryId: _houseFactoryId
        });

        deploymentInfoForToken[address(token)] = deploymentInfo;
        tokensDeployedByUsers[_payout].push(deploymentInfo);

        emit TokenCreated(
            address(token),
            positionId,
            _creator,
            _payout,
            _name,
            _symbol,
            _supply,
            address(liquidityLocker),
            _houseFactoryId
        );
    }

    function toggleAllowedPairedToken(
        address token,
        bool allowed
    ) external onlyOwner {
        allowedPairedTokens[token] = allowed;
    }

    function claimRewards(address token) external {
        DeploymentInfo memory deploymentInfo = deploymentInfoForToken[token];

        if (deploymentInfo.token == address(0)) revert TokenNotFound(token);

        ILocker(deploymentInfo.locker).collectRewards(
            deploymentInfo.positionId
        );
    }

    function setDeprecated(bool _deprecated) external onlyOwner {
        deprecated = _deprecated;
    }

    function updateLiquidityLocker(address newLocker) external onlyOwner {
        liquidityLocker = AvaryHouse(newLocker);
    }
}

/// @notice Given a tickSpacing, compute the maximum usable tick
function maxUsableTick(int24 tickSpacing) pure returns (int24) {
    unchecked {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}