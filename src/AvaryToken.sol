// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract AvaryToken is ERC20, ERC20Permit, ERC20Votes, ERC20Burnable {
    error NotCreator();

    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    address private immutable _creator;
    address private immutable _payout;
    string private _image;
    bytes32 private immutable _houseFactoryId;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address creator_,
        address payout_,
        string memory image_,
        bytes32 houseFactoryId_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _creator = creator_;
        _payout = payout_;
        _image = image_;
        _houseFactoryId = houseFactoryId_;
        _mint(msg.sender, maxSupply_);
    }

    function updateImage(string memory image_) public {
        if (msg.sender != _creator) {
            revert NotCreator();
        }
        _image = image_;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function creator() public view returns (address) {
        return _creator;
    }

    function payout() public view returns (address) {
        return _payout;
    }

    function image() public view returns (string memory) {
        return _image;
    }

    function houseFactoryId() public view returns (bytes32) {
        return _houseFactoryId;
    }
}
