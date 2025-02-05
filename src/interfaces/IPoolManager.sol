// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./IFactory.sol";

interface IPoolManager is IFactory {
    struct PoolInfo {
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint8 feeProtocol; // 低 4 位表示 token0 的协议抽取费用比例。高 4 位表示 token1 的协议费用比例。
        int24 tickLower;
        int24 tickUpper;
        int24 tick;
        uint160 sqrtPriceX96;
    }

    struct Pair {
        address token0;
        address token1;
    }

    function getPairs() external view returns (Pair[] memory);

    function getAllPools() external view returns (PoolInfo[] memory poolsInfo);

    struct CreateAndInitializeParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtPriceX96; // 事实上, 创建 pool 时只用了上面 5 个字段
    }

    function createAndInitializePoolIfNecessary(CreateAndInitializeParams calldata params)
        external
        payable
        returns (address pool);
}
