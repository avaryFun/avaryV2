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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract AvaryToken is ERC20, ERC20Permit, ERC20Votes, ERC20Burnable {
    error NotDeployer();

    string private _name;
    string private _symbol;
    uint8 private immutable _decimals;

    address private _deployer;
    string private _image;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address deployer_,
        string memory image_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _deployer = deployer_;
        _image = image_;
        _mint(msg.sender, maxSupply_);
    }

    function updateImage(string memory image_) public {
        if (msg.sender != _deployer) {
            revert NotDeployer();
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

    function deployer() public view returns (address) {
        return _deployer;
    }

    function image() public view returns (string memory) {
        return _image;
    }
}
