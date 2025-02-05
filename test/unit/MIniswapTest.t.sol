// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "../../src/Pool.sol";
import {Factory} from "../../src/Factory.sol";
import {PositionManager} from "../../src/PositionManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {TestToken} from "../mock/TestToken.sol";

contract MiniswapTest is Test {
    Factory factory;
    PositionManager positionmanager;
    Pool pool;
    TestToken token0;
    TestToken token1;
    
    uint256 public tickLower;
    uint256 public tickUpper;
    uint256 public fee = 3000;
    uint256 public sqrtPriceX96;

    address public USER = makeAddr("user");
    uint256 public constant TK_BALANCE = 100 ether;
    uint256 public constant SWAP_MINT = 10 ether;


    function setUp() external {
        factory = new Factory(); // pool is created by factory
        TestToken tkA = new TestToken();
        TestToken tkB = new TestToken();
        tkA.mint(USER, TK_BALANCE);
        tkB.mint(USER, TK_BALANCE);
        if (address(tkA) < address(tkB)) {
            token0 = tkA;
            token1 = tkB;
        } else {
            token0 = tkB;
            token1 = tkA;
        }

        vm.startPrank(USER);





    }

    









    /**
     * @dev msg.sender of test && contract address
     * attempt 1: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
     * attempt 2: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
     */
    function testSenderAndThis() public {
        console.log(msg.sender);
        console.log(address(this));
    }
}
