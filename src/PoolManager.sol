// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./Factory.sol";
import "./interfaces/IPool.sol";

contract PoolManager is Factory, IPoolManager {
    Pair[] public pairs;

    // 返回 pair 数组全部数据
    function getPairs() external view override returns (Pair[] memory) {
        return pairs;
    }

    function getAllPools() external view override returns (PoolInfo[] memory poolsInfo) {
        uint32 length = 0;
        // 计算所有池子的数量
        // pairs 同时也可以作为 pools 的 key, 否则作为 mapping 的 pools 无法迭代返回
        for (uint32 i = 0; i < pairs.length; i++) {
            length += uint32(pools[pairs[i].token0][pairs[i].token1].length);
        }

        // 再填充数据
        poolsInfo = new PoolInfo[](length);
        for (uint32 i = 0; i < pairs.length; i++) {
            address[] memory addresses = pools[pairs[i].token0][pairs[i].token1];
            for (uint32 j = 0; j < addresses.length; j++) {
                IPool pool = IPool(addresses[j]);
                poolsInfo[i + j] = PoolInfo({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    index: j,
                    fee: pool.fee(),
                    feeProtocol: 0,
                    tickLower: pool.tickLower(),
                    tickUpper: pool.tickUpper(),
                    tick: pool.tick(),
                    sqrtPriceX96: pool.sqrtPriceX96()
                });
            }
        }
        return poolsInfo;
    }

    function createAndInitializePoolIfNecessary(CreateAndInitializeParams calldata params)
        external
        payable
        override
        returns (address poolAddress)
    {
        require(
            // params 中需要传入交易价格(按照 token0/token1 的方式计算)
            // 因此防止用户搞错 token0 和 token1 的顺序进而搞错价格
            params.token0 < params.token1,
            "token0 must be less than token1"
        );

        poolAddress = this.createPool(params.token0, params.token1, params.tickLower, params.tickUpper, params.fee);

        IPool pool = IPool(poolAddress);

        uint256 index = pools[pool.token0()][pool.token1()].length;

        // 新创建的池子，没有初始化价格，需要初始化价格
        // 但是这个价格是如何指定的? 正常来说应该需要根据 token0 和 token1 的数量算出来???
        if (pool.sqrtPriceX96() == 0) {
            pool.initialize(params.sqrtPriceX96);

            if (index == 1) {
                // 如果是第一次添加该交易对，需要记录到 pairs 中
                pairs.push(Pair({token0: pool.token0(), token1: pool.token1()}));
            }
        }
    }
}
