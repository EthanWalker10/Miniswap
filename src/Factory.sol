// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./Pool.sol";

contract Factory is IFactory {
    mapping(address => mapping(address => address[])) public pools;

    Parameters public override parameters;

    // make sure that token0 < token1
    function sortToken(
        address tokenA,
        address tokenB
    ) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint32 index // 当前 pair 对应的 pool 数组的索引
    ) external view override returns (address) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

        // Declare token0 and token1
        address token0;
        address token1;

        (token0, token1) = sortToken(tokenA, tokenB);

        return pools[token0][token1][index];
    }

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override returns (address pool) {
        // validate token's individuality
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

        // Declare token0 and token1
        address token0;
        address token1;

        // sort token, avoid the mistake of the order
        (token0, token1) = sortToken(tokenA, tokenB);

        // get current all pools
        address[] memory existingPools = pools[token0][token1];

        // check if the pool already exists
        // 考虑可行的 gas 优化
        for (uint256 i = 0; i < existingPools.length; i++) {
            IPool currentPool = IPool(existingPools[i]);

            if (
                currentPool.tickLower() == tickLower &&
                currentPool.tickUpper() == tickUpper &&
                currentPool.fee() == fee
            ) {
                return existingPools[i];
            }
        }

        // save pool info
        parameters = Parameters(
            address(this),
            token0,
            token1,
            tickLower,
            tickUpper,
            fee
        );

        // generate create2 salt
        bytes32 salt = keccak256(
            abi.encode(token0, token1, tickLower, tickUpper, fee)
        );

        // create pool
        // pool 被创建时在 constructor 中反向获取参数
        // pool 自动作为 createPool 函数的返回, 但是在真实环境中不能作为判断是否成果, 需要通过事件来监听 Pool 的创建
        pool = address(new Pool{salt: salt}());

        // save created pool
        pools[token0][token1].push(pool);

        // delete pool info
        delete parameters;

        emit PoolCreated(
            token0,
            token1,
            uint32(existingPools.length),
            tickLower,
            tickUpper,
            fee,
            pool
        );
    }
}
