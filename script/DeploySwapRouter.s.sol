// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "../src/PoolManager.sol";

contract DepolyPoolManger is Script {
    address public ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public MAINNET_ACCOUNT = 0x67612F0D87a3A6bBc13074Bf54c0500dbA12f4D4;
    address public SEPOLIA_ACCOUNT = 0x67612F0D87a3A6bBc13074Bf54c0500dbA12f4D4;
    function run() external returns (PoolManager poolManager) {
        address account;
        if (block.chainid == 1) {
            account = MAINNET_ACCOUNT;
        } else if (block.chainid == 42) {
            account = SEPOLIA_ACCOUNT;
        } else {
            account = ANVIL_ACCOUNT;
        }

        vm.startBroadcast(account);
        poolManager = new PoolManager();
        vm.stopBroadcast();
    }
}