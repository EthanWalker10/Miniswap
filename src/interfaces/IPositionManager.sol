// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPositionManager is IERC721 {
    struct PositionInfo {
        address owner;
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        // feeGrowthInside0LastX128 和 feeGrowthInside1LastX128 用于计算手续费
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    function getAllPositions()
        external
        view
        returns (PositionInfo[] memory positionInfo);

    struct MintParams {
        // token0, token1, index 定位具体的 pool
        address token0;
        address token1;
        uint32 index;
        // 用户希望存入的代币数量
        uint256 amount0Desired;
        uint256 amount1Desired;
        // 接受 Lp token 的地址
        address recipient;
        // 指定的操作截至时间, 到时间如果没有执行则会取消
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 positionId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function burn(
        uint256 positionId
    ) external returns (uint256 amount0, uint256 amount1);

    function collect(
        uint256 positionId,
        address recipient
    ) external returns (uint256 amount0, uint256 amount1);

    function mintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
