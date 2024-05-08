// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Token} from "../../src/ERC20Token.sol";
import {NFTContract} from "./../../src/NFTContract.sol";

contract HelperConfig is Script {
    // deployment arguments
    address public constant TOKENOWNER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    string public constant NAME = "NFT Collection";
    string public constant SYMBOL = "MYNFT";
    string public constant BASE_URI =
        "ipfs://bafybeihgsbcbmy3k3iowwhwv2kabdnvwsp2tee5bfm5yzwjvw7roc52spm/";
    string public constant CONTRACT_URI =
        "ipfs://bafybeihgsbcbmy3k3iowwhwv2kabdnvwsp2tee5bfm5yzwjvw7roc52spm/";
    uint256 public constant MAX_SUPPLY = 1000;

    // chain configurations
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        NFTContract.ConstructorArguments args;
    }

    constructor() {
        if (
            block.chainid == 1 || block.chainid == 56 || block.chainid == 8453
        ) {
            activeNetworkConfig = getMainnetConfig();
        } else if (
            block.chainid == 11155111 ||
            block.chainid == 97 ||
            block.chainid == 84532 ||
            block.chainid == 84531 ||
            block.chainid == 80001
        ) {
            activeNetworkConfig = getTestnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getActiveNetworkConfigStruct()
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                args: NFTContract.ConstructorArguments({
                    name: NAME,
                    symbol: SYMBOL,
                    owner: 0x4671a210C4CF44C43dC5E44DAf68e64D46cdc703,
                    feeAddress: 0x0d8470Ce3F816f29AA5C0250b64BfB6421332829,
                    tokenAddress: 0xB0BcB4eDE80978f12aA467F7344b9bdBCd2497f3,
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    maxSupply: MAX_SUPPLY
                })
            });
    }

    function getTestnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                args: NFTContract.ConstructorArguments({
                    name: NAME,
                    symbol: SYMBOL,
                    owner: 0xCbA52038BF0814bC586deE7C061D6cb8B203f8e1,
                    feeAddress: 0xCbA52038BF0814bC586deE7C061D6cb8B203f8e1,
                    tokenAddress: 0x17cE1F8De9235EC9aACd58c56de5F8eA4bD8E063,
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    maxSupply: MAX_SUPPLY
                })
            });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        // Deploy mock contract
        vm.startBroadcast();
        ERC20Token token = new ERC20Token(TOKENOWNER);
        vm.stopBroadcast();

        return
            NetworkConfig({
                args: NFTContract.ConstructorArguments({
                    name: NAME,
                    symbol: SYMBOL,
                    owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                    feeAddress: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                    tokenAddress: address(token),
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    maxSupply: MAX_SUPPLY
                })
            });
    }
}
