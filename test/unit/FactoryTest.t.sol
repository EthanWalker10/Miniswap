// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestToken} from "../mock/TestToken.sol";
import {Factory} from "../../src/Factory.sol";
import {IFactory} from "../../src//interfaces/IFactory.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";


contract PoolTest is Test {
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

    function testGetUncreatedPool() public {
        vm.expectRevert();
        address pool = factory.getPool(address(token0), address(token1), 0);
    }

    function testCreatePool() public {
        vm.expectEmit();
        emit IFactory.PoolCreated(address(token0), address(token1), 0, 10, 100, 3000, 0x686E00a6ff0624d0F7E723DD9e726dFB6aCB3248);
        address pool = factory.createPool(
            address(token0),
            address(token1),
            10,
            100,
            3000
        );

        // vm.expectEmit(true, true, true, false);
        // emit IFactory.PoolCreated(address(token0), address(token1), 0, 10, 100, 3000, 0x686E00a6ff0624d0F7E723DD9e726dFB6aCB3248);
        // address pool = factory.createPool(
        //     address(token0),
        //     address(token1),
        //     10,
        //     100,
        //     3000
        // );
    }

    function testGetCreatedPool() public {
        address pool = factory.createPool(
            address(token0),
            address(token1),
            10,
            100,
            3000
        );

        assertEq(pool, factory.getPool(address(token0), address(token1), 0));
    }
}