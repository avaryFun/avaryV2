// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {NonFungibleContract} from "./IManager.sol";

contract AvaryHouse is Ownable, IERC721Receiver {
    event LockId(uint256 _id);
    event Received(address indexed from, uint256 tokenId);
    event HouseFactoryRegistered(
        bytes32 indexed houseFactoryId,
        string name,
        address indexed owner,
        address indexed payout,
        string description
    );

    error NotAllowed(address user);
    error InvalidTokenId(uint256 tokenId);
    error TokenStillLocked(uint256 tokenId);
    error NameAlreadyUsed(string name);
    error InvalidHouseConfig();
    error HouseFactoryNotFound(bytes32 houseFactoryId);

    event ClaimedRewards(
        address indexed claimer,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 totalAmount0,
        uint256 totalAmount1
    );

    IERC721 private SafeERC721;
    address private immutable e721Token;
    address public immutable positionManager;
    string public constant version = "0.0.2";
    address public _factory;

    // Lock duration in seconds (60 years)
    uint256 public constant LOCK_DURATION = 60 * 365 days;
    
    // Fixed reward percentages
    uint256 public constant HOUSE_REWARD_PERCENTAGE = 10; // 10% for house
    uint256 public constant CREATOR_REWARD_PERCENTAGE = 90; // 90% for creator
    
    // Mapping to store lock end time for each token
    mapping(uint256 => uint256) public tokenLockEndTime;

    struct HouseFactory {
        string name;
        address owner;
        address payout;
        string description;
        bool active;
    }

    // Mapping for house factories using bytes32 as unique ID
    mapping(bytes32 => HouseFactory) public houseFactories;
    mapping(string => bool) public usedHouseNames;
    
    // Mapping token to house factory
    mapping(uint256 => bytes32) public tokenToHouseFactory;

    struct UserRewardRecipient {
        address recipient;
        uint256 lpTokenId;
        bytes32 houseFactoryId;
    }

    mapping(uint256 => UserRewardRecipient) public _userRewardRecipientForToken;
    mapping(address => uint256[]) public _userTokenIds;

    constructor(
        address tokenFactory,
        address token,
        address owner_,
        address positionManager_
    ) Ownable(owner_) {
        SafeERC721 = IERC721(token);
        e721Token = token;
        _factory = tokenFactory;
        positionManager = positionManager_;
    }

    modifier onlyOwnerOrFactory() {
        if (msg.sender != owner() && msg.sender != _factory) {
            revert NotAllowed(msg.sender);
        }
        _;
    }

    function generateHouseFactoryId(
        string memory name,
        address owner
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(name, owner));
    }

    function registerHouseFactory(
        string memory name,
        address owner,
        address payout,
        string memory description
    ) external onlyOwner returns (bytes32 houseFactoryId) {
        if (bytes(name).length == 0 || owner == address(0) || payout == address(0)) {
            revert InvalidHouseConfig();
        }

        if (usedHouseNames[name]) {
            revert NameAlreadyUsed(name);
        }

        houseFactoryId = generateHouseFactoryId(name, owner);
        
        houseFactories[houseFactoryId] = HouseFactory({
            name: name,
            owner: owner,
            payout: payout,
            description: description,
            active: true
        });

        usedHouseNames[name] = true;

        emit HouseFactoryRegistered(
            houseFactoryId,
            name,
            owner,
            payout,
            description
        );
    }

    function addUserRewardRecipient(
        UserRewardRecipient memory recipient
    ) public onlyOwnerOrFactory {
        if (!houseFactories[recipient.houseFactoryId].active) {
            revert HouseFactoryNotFound(recipient.houseFactoryId);
        }

        _userRewardRecipientForToken[recipient.lpTokenId] = recipient;
        _userTokenIds[recipient.recipient].push(recipient.lpTokenId);
        
        // Set lock end time when adding new recipient
        tokenLockEndTime[recipient.lpTokenId] = block.timestamp + LOCK_DURATION;
    }

    function collectRewards(uint256 _tokenId) public {
        UserRewardRecipient memory userRewardRecipient = _userRewardRecipientForToken[_tokenId];
        address _recipient = userRewardRecipient.recipient;

        if (_recipient == address(0)) {
            revert InvalidTokenId(_tokenId);
        }

        bytes32 houseFactoryId = userRewardRecipient.houseFactoryId;
        HouseFactory memory house = houseFactories[houseFactoryId];
        
        if (!house.active) {
            revert HouseFactoryNotFound(houseFactoryId);
        }

        NonFungibleContract nonfungiblePositionManager = NonFungibleContract(positionManager);

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
            NonFungibleContract.CollectParams({
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                tokenId: _tokenId
            })
        );

        (, , address token0, address token1, , , , , , , , ) = nonfungiblePositionManager.positions(_tokenId);

        IERC20 rewardToken0 = IERC20(token0);
        IERC20 rewardToken1 = IERC20(token1);

        // Calculate rewards with fixed percentages
        uint256 houseReward0 = (amount0 * HOUSE_REWARD_PERCENTAGE) / 100;
        uint256 houseReward1 = (amount1 * HOUSE_REWARD_PERCENTAGE) / 100;

        uint256 creatorReward0 = amount0 - houseReward0;
        uint256 creatorReward1 = amount1 - houseReward1;

        // Check if token0 is still locked
        if (block.timestamp < tokenLockEndTime[_tokenId]) {
            // If locked, only transfer token1 rewards
            rewardToken1.transfer(_recipient, creatorReward1);
            rewardToken1.transfer(house.payout, houseReward1);
        } else {
            // If unlocked, transfer both token rewards
            rewardToken0.transfer(_recipient, creatorReward0);
            rewardToken1.transfer(_recipient, creatorReward1);
            rewardToken0.transfer(house.payout, houseReward0);
            rewardToken1.transfer(house.payout, houseReward1);
        }

        emit ClaimedRewards(
            _recipient,
            token0,
            token1,
            creatorReward0,
            creatorReward1,
            amount0,
            amount1
        );
    }

    function updateAvaryFactory(address newFactory) public onlyOwner {
        _factory = newFactory;
    }

    function getLpTokenIdsForUser(
        address user
    ) public view returns (uint256[] memory) {
        return _userTokenIds[user];
    }

    function onERC721Received(
        address,
        address from,
        uint256 id,
        bytes calldata
    ) external override returns (bytes4) {
        if (from != _factory) {
            revert NotAllowed(from);
        }

        emit Received(from, id);
        return IERC721Receiver.onERC721Received.selector;
    }
}