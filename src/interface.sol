// SPDX-License-Identifier: MIT
//                                                   
//                                                   
//  /$$$$$$  /$$    /$$ /$$$$$$   /$$$$$$  /$$   /$$
// |____  $$|  $$  /$$/|____  $$ /$$__  $$| $$  | $$
//  /$$$$$$$ \  $$/$$/  /$$$$$$$| $$  \__/| $$  | $$
// /$$__  $$  \  $$$/  /$$__  $$| $$      | $$  | $$
//|  $$$$$$$   \  $/  |  $$$$$$$| $$      |  $$$$$$$
// \_______/    \_/    \_______/|__/       \____  $$
//                                         /$$  | $$
//                                        |  $$$$$$/
//                                         \______/
pragma solidity ^0.8.25;

/// @title Uniswap V3 Interfaces for Avalanche
/// @notice These interfaces are used for interacting with Uniswap V3 on Avalanche C-Chain

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method call to the pool to initialize it will be required before initialization.
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /// @notice Creates a new pool if it does not exist, then initializes if not initialized
    /// @dev This method can be bundled with others via IMulticall for the first action (e.g. mint) performed against a pool
    /// @param token0 The contract address of token0 of the pool
    /// @param token1 The contract address of token1 of the pool
    /// @param fee The fee amount of the v3 pool for the specified token pair
    /// @param sqrtPriceX96 The initial square root price of the pool as a Q64.96 value
    /// @return pool Returns the pool address based on the pair of tokens and fee, will return the newly created pool address if necessary
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity
    /// @param params The params necessary to collect tokens, encoded as CollectParams in calldata
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Transfers the NFT to recipient
    /// @dev Safe transfer rules apply
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

interface IUniswapV3Factory {
    /// @notice Initializes the pool with the given price
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Creates a pool for the given two tokens and fee
    /// @param tokenA The first token of the pool by address sort order
    /// @param tokenB The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The address of the newly created pool
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /// @notice Returns the tick spacing for a given fee amount
    /// @dev Tick spacing is the minimum tick movement for the given fee tier
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
}

interface ILockerFactory {
    /// @notice Deploys a new locker contract
    /// @param beneficiary The address that will receive the fees
    /// @param fees The percentage of fees to be collected
    function deploy(
        address beneficiary,
        uint256 fees
    ) external payable returns (address);
}

interface ILocker {
    /// @notice Initializes the locker with position IDs
    function initializer(
        uint256 wavaxPositionId,
        uint256 avaryPositionId
    ) external;

    /// @notice Collects rewards for a given token ID
    function collectRewards(uint256 _tokenId) external;
}

/// @notice Parameters for performing an exact input swap on Avalanche
struct ExactInputSingleParams {
    address tokenIn;      // The token being swapped in
    address tokenOut;     // The token being swapped out
    uint24 fee;          // The fee tier of the pool
    address recipient;    // The recipient of the swap
    uint256 amountIn;    // The amount of input tokens
    uint256 amountOutMinimum; // The minimum amount of output tokens
    uint160 sqrtPriceLimitX96; // The Q64.96 sqrt price limit
}

interface ISwapRouter {
    /// @notice Swaps amountIn of one token for as much as possible of another token on Avalanche
    /// @param params The parameters necessary for the swap, encoded as ExactInputSingleParams in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
} 