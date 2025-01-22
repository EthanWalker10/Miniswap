// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestToken} from "../mock/TestToken.sol";
import {PoolManager} from "../../src/PoolManager.sol";
import {IPoolManager, IFactory} from "../../src/interfaces/IPoolManager.sol";
import {PositionManager} from "../../src/PositionManager.sol";
import {IPositionManager} from "../../src/interfaces/IPositionManager.sol";
import {Test, console2} from "forge-std/Test.sol";


contract PoolManagerTest is Test {
    PoolManager poolManager;
    PositionManager positionManager;
    TestToken tkA;
    TestToken tkB;
    TestToken tkC;
    TestToken tkD;
    uint24 constant FEE = 3000;
    int24 constant TICKLOWER = 84222; // price_low: sqrt(4545) -> tick_i
    int24 constant TICKUPPER = 86129; // price_up: sqrt(5500) -> tick_i
    uint160 SQRTPRICEX96 = 5602277097478614198912276234240; // sqrt(5000) * 2^96

    IPoolManager.CreateAndInitializeParams public createParams1;
    IPoolManager.CreateAndInitializeParams public createParams2;
    IPoolManager.CreateAndInitializeParams public createParams3;
    IPoolManager.CreateAndInitializeParams public createParams4;

    IPositionManager.MintParams public params1;

    address public LP = makeAddr("lp");

    function sortTokens(address a, address b) public pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }


    function setUp() external {
        poolManager = new PoolManager();
        positionManager = new PositionManager(address(poolManager));
        tkA = new TestToken();
        tkB = new TestToken();
        tkC = new TestToken();
        tkD = new TestToken();



        createParams1 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkA),
            token1: address(tkB),
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        createParams2 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkA),
            token1: address(tkB),
            fee: FEE,
            tickLower: TICKLOWER+100,
            tickUpper: TICKUPPER+100,
            sqrtPriceX96: SQRTPRICEX96
        });

        createParams3 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkC),
            token1: address(tkD),
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        createParams4 = IPoolManager.CreateAndInitializeParams({
            token0: address(tkB),
            token1: address(tkC),
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        address pool1 = poolManager.createAndInitializePoolIfNecessary(createParams1);
        address pool2 = poolManager.createAndInitializePoolIfNecessary(createParams2);
        address pool3 = poolManager.createAndInitializePoolIfNecessary(createParams3);
        address pool4 = poolManager.createAndInitializePoolIfNecessary(createParams4);

        params1 = IPositionManager.MintParams({
            token0: address(tkA),
            token1: address(tkB),
            index: 0,
            amount0Desired: 1,
            amount1Desired: 5000,
            recipient: LP,
            deadline: block.timestamp + 600
        });


    }

    function testMintAfterDeadline() public {
        vm.warp(block.timestamp + 3600); 
        vm.expectRevert();
        positionManager.mint(params1);
    }


}