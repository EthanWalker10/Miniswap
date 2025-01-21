// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestToken} from "../mock/TestToken.sol";
import {PoolManager} from "../../src/PoolManager.sol";
import {IPoolManager, IFactory} from "../../src/interfaces/IPoolManager.sol";
import {Test, console2, Vm} from "forge-std/Test.sol";


contract PoolManagerTest is Test {
    PoolManager poolManager;
    TestToken tkA;
    TestToken tkB;
    TestToken tkC;
    TestToken tkD;
    uint24 constant FEE = 3000;
    int24 constant TICKLOWER = 84222; // price_low: sqrt(4545) -> tick_i
    int24 constant TICKUPPER = 86129; // price_up: sqrt(5500) -> tick_i
    uint160 SQRTPRICEX96 = 5602277097478614198912276234240; // sqrt(5000) * 2^96
    IPoolManager.CreateAndInitializeParams public params1;
    IPoolManager.CreateAndInitializeParams public params2;
    IPoolManager.CreateAndInitializeParams public params3;



    function setUp() external {
        poolManager = new PoolManager();
        tkA = new TestToken();
        tkB = new TestToken();
        tkC = new TestToken();
        tkD = new TestToken();

        params1 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkA),
            token1: address(tkB),
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        params2 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkA),
            token1: address(tkB),
            fee: FEE,
            tickLower: TICKLOWER+100,
            tickUpper: TICKUPPER+100,
            sqrtPriceX96: SQRTPRICEX96
        });

        params3 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkC),
            token1: address(tkD),
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });
    }

    function testGetPairsIfNotExist() public {
        PoolManager.Pair[] memory pairs = poolManager.getPairs();
        /* got error: log can not print struct */
        // console2.log(pairs);
        console2.log(pairs.length);
        vm.expectRevert();
        console2.log(pairs[0].token0);
    }

    function testCreateAndInitializePool() public {
        vm.expectEmit();
        emit IFactory.PoolCreated(
            address(tkA), 
            address(tkB), 
            0, TICKLOWER, TICKUPPER, FEE, 0x6c68Dd2c016656BFe7B45675675b46cBbd829A4F
        );
        address poolAddress = poolManager.createAndInitializePoolIfNecessary(params1);
        console2.log("deployed pool address:", poolAddress);
    }


    /*//////////////////////////////////////////////////////////////
                            PoolAlreadyExists
    //////////////////////////////////////////////////////////////*/

    modifier poolCreated() {
        address pool1 = poolManager.createAndInitializePoolIfNecessary(params1);
        address pool2 = poolManager.createAndInitializePoolIfNecessary(params2);
        address pool3 = poolManager.createAndInitializePoolIfNecessary(params3);
        _;
    }

    function testGetPairs() public poolCreated {
        PoolManager.Pair[] memory pairs = poolManager.getPairs();
        assertEq(pairs[0].token0, params1.token0);
        assertEq(pairs[0].token1, params1.token1);
        assertEq(pairs[1].token0, params3.token0);
        assertEq(pairs[1].token1, params3.token1);
    }

    function test


}