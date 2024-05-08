// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Token is ERC20, Ownable {
    constructor(address initialOwner) ERC20("FLAMELING", "0X177") Ownable(initialOwner) {
        _mint(initialOwner, 1_000_000_000 * 10 ** decimals());
    }
}
