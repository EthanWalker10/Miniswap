// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "../../src/Pool.sol";
import {Factory} from "../../src/Factory.sol";
import {Test, console} from "forge-std/Test.sol";
import {TestToken} from "../mock/TestToken.sol";

contract PoolTest is Test {
    Pool pool;
    Factory factory;

    TestToken token0;
    TestToken token1;

    function setUp() external {
        factory = new Factory();
        TestToken tkA = new TestToken();
        TestToken tkB = new TestToken();
        if (address(tkA) < address(tkB)) {
            token0 = tkA;
            token1 = tkB;
        } else {
            token0 = tkB;
            token1 = tkA;
        }

    }

}