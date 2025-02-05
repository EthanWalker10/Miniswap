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
    address token0;
    address token1;
    address token2;
    uint24 constant FEE = 3000;
    int24 constant TICKLOWER = 84222; // price_low: sqrt(4545) -> tick_i
    int24 constant TICKUPPER = 86129; // price_up: sqrt(5500) -> tick_i
    uint160 SQRTPRICEX96 = 5602277097478614198912276234240; // sqrt(5000) * 2^96

    IPoolManager.CreateAndInitializeParams public createParams1;
    IPoolManager.CreateAndInitializeParams public createParams2;
    IPoolManager.CreateAndInitializeParams public createParams3;

    IPositionManager.MintParams public params1;

    address public LP = makeAddr("lp");
    uint256 constant BALANCE0 = 1;
    uint256 constant BALANCE1 = 5000;
    uint256 constant BALANCE2 = 5000;


    function sortTokens(address a, address b) public pure returns (address, address) {
        return a < b ? (a, b) : (b, a);
    }


    function setUp() external {
        poolManager = new PoolManager();
        positionManager = new PositionManager(address(poolManager));
        tkA = new TestToken();
        tkB = new TestToken();
        tkC = new TestToken();

        (token0, token1) = sortTokens(address(tkA), address(tkB));
        (token0, token2) = sortTokens(token0, address(tkC));
        (token1, token2) = sortTokens(token1, token2);

        if (block.chainid == 31337) {
            TestToken(token0).mint(LP, BALANCE0);
            TestToken(token1).mint(LP, BALANCE1);
            TestToken(token2).mint(LP, BALANCE2);
        }
        vm.startPrank(LP);
        TestToken(token0).approve(address(positionManager), BALANCE0);
        TestToken(token1).approve(address(positionManager), BALANCE1);
        TestToken(token2).approve(address(positionManager), BALANCE2);
        vm.stopPrank();

        createParams1 = IPoolManager.CreateAndInitializeParams({
            token0: token0,
            token1: token1,
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        createParams2 = IPoolManager.CreateAndInitializeParams({
            token0: token0,
            token1: token1,
            fee: FEE,
            tickLower: TICKLOWER+100,
            tickUpper: TICKUPPER+100,
            sqrtPriceX96: SQRTPRICEX96
        });

        createParams3 = IPoolManager.CreateAndInitializeParams({
            token0: token1,
            token1: token2,
            fee: FEE,
            tickLower: TICKLOWER,
            tickUpper: TICKUPPER,
            sqrtPriceX96: SQRTPRICEX96
        });

        address pool1 = poolManager.createAndInitializePoolIfNecessary(createParams1);
        address pool2 = poolManager.createAndInitializePoolIfNecessary(createParams2);
        address pool3 = poolManager.createAndInitializePoolIfNecessary(createParams3);

        params1 = IPositionManager.MintParams({
            token0: token0,
            token1: token1,
            index: 0,
            amount0Desired: 2,
            amount1Desired: 10000,
            recipient: LP,
            deadline: block.timestamp + 600
        });

    }

    function testMintAfterDeadline() public {
        vm.warp(block.timestamp + 3600); 
        vm.expectRevert();
        positionManager.mint(params1);
    }

    /**
     * 1. how to calculate the liquidity?
     * 2. if we need to mint first? 
     * assert if the liquidity, amount0, amount1 is coordinate to what we predict
     */
    function testMintParams() public {
        vm.prank(LP);
        (uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.mint(params1);
        console2.log(positionId, liquidity, amount0, amount1);

        // compare the result with that we predict(mathmatic calculating)
        
    }


}