// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/SqrtPriceMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SwapMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IFactory.sol";

contract Pool is IPool {
    using SafeCast for uint256;
    using LowGasSafeMath for int256;
    using LowGasSafeMath for uint256;

    /// @inheritdoc IPool
    address public immutable override factory;
    /// @inheritdoc IPool
    address public immutable override token0;
    /// @inheritdoc IPool
    address public immutable override token1;
    /// @inheritdoc IPool
    uint24 public immutable override fee;
    /// @inheritdoc IPool
    int24 public immutable override tickLower;
    /// @inheritdoc IPool
    int24 public immutable override tickUpper;

    /// @inheritdoc IPool
    uint160 public override sqrtPriceX96;
    /// @inheritdoc IPool
    int24 public override tick;
    /// @inheritdoc IPool
    uint128 public override liquidity;

    /// @inheritdoc IPool
    // 全局费用增长, 每次 token0 -> token1 交易（swap）中产生的交易费不断累加形成的
    uint256 public override feeGrowthGlobal0X128;
    /// @inheritdoc IPool
    // token1 -> token0
    uint256 public override feeGrowthGlobal1X128;

    struct Position {
        // 该 Position 拥有的流动性
        uint128 liquidity;
        // 可提取的 token0 数量
        uint128 tokensOwed0;
        // 可提取的 token1 数量
        uint128 tokensOwed1;
        // 上次提取手续费时的 feeGrowthGlobal0X128
        uint256 feeGrowthInside0LastX128;
        // 上次提取手续费是的 feeGrowthGlobal1X128
        uint256 feeGrowthInside1LastX128;
    }

    // 用一个 mapping 来存放所有 Position 的信息
    mapping(address => Position) public positions;

    constructor() {
        // constructor 中初始化 immutable 的常量
        // Factory 创建 Pool 时会通 new Pool{salt: salt}() 的方式创建 Pool 合约，通过 salt 指定 Pool 的地址，这样其他地方也可以推算出 Pool 的地址
        // 参数通过读取 Factory 合约的 parameters 获取
        // 不通过构造函数传入，因为 CREATE2 会根据 initcode 计算出新地址（new_address = hash(0xFF, sender, salt, bytecode)），带上参数就不能计算出稳定的地址了
        (factory, token0, token1, tickLower, tickUpper, fee) = IFactory(msg.sender).parameters();
    }

    function initialize(uint160 sqrtPriceX96_) external override {
        require(sqrtPriceX96 == 0, "INITIALIZED");
        // 通过价格获取 tick，判断 tick 是否在 tickLower 和 tickUpper 之间
        tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96_);
        require(
            tick >= tickLower && tick < tickUpper, "sqrtPriceX96 should be within the range of [tickLower, tickUpper)"
        );
        // 初始化 Pool 的 sqrtPriceX96
        sqrtPriceX96 = sqrtPriceX96_;
    }

    struct ModifyPositionParams {
        address owner;
        int128 liquidityDelta;
    }

    /**
     * @dev 修改用户的 Position 信息
     * @dev 通过 Storage 引用实现 gas saving
     */
    function _modifyPosition(ModifyPositionParams memory params) private returns (int256 amount0, int256 amount1) {
        // 通过新增的流动性计算 amount0 和 amount1
        // 参考 UniswapV3 的代码
        amount0 =
            SqrtPriceMath.getAmount0Delta(sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickUpper), params.liquidityDelta);

        amount1 =
            SqrtPriceMath.getAmount1Delta(TickMath.getSqrtPriceAtTick(tickLower), sqrtPriceX96, params.liquidityDelta);
        // gas saving
        // 直接通过 position 引用访问和修改数据，不需要每次都进行 mapping 查找，从而减少了多次存储读取带来的 Gas 开销。
        // 使用 storage 引用时，在本地内存中进行数据的操作。只有在函数返回时才将数据修改写回到存储。这种方式可以在一个地方集中进行数据修改，避免了对存储的多次修改。
        Position storage position = positions[params.owner];

        // 提取手续费，计算从上一次提取到当前的手续费
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal0X128 - position.feeGrowthInside0LastX128, position.liquidity, FixedPoint128.Q128
            )
        );
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal1X128 - position.feeGrowthInside1LastX128, position.liquidity, FixedPoint128.Q128
            )
        );

        position.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
        position.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            position.tokensOwed0 += tokensOwed0;
            position.tokensOwed1 += tokensOwed1;
        }

        liquidity = LiquidityMath.addDelta(liquidity, params.liquidityDelta);
        position.liquidity = LiquidityMath.addDelta(position.liquidity, params.liquidityDelta);
    }

    /**
     * @dev 在传统的调用中，如果不做优化，通常需要先检查目标地址是否为合约（extcodesize）并验证返回数据的大小（returndatasize）
     * @dev 但 staticcall 已经隐式执行了这两个检查，避免了冗余的 Gas 消耗。
     * @dev 在 V3 中定义了 IERC20Minimal 来最小化一个 ERC20 的体量(去掉了不需要的方法等部分)
     */
    function balance0() private view returns (uint256) {
        // staticcall: 只读调用，避免更昂贵的写入操作
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }
    /**
     * @dev 添加流动性
     * @param amount: 添加的流动性份额，根据 amount 计算出需要的两种代币数量 amount0 和 amount1
     */

    function mint(address recipient, uint128 amount, bytes calldata data)
        external
        override
        returns (uint256 amount0, uint256 amount1)
    {
        require(amount > 0, "Mint amount must be greater than 0");
        (int256 amount0Int, int256 amount1Int) =
            _modifyPosition(ModifyPositionParams({owner: recipient, liquidityDelta: int128(amount)}));
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IMintCallback(msg.sender).mintCallback(amount0, amount1, data);

        if (amount0 > 0) {
            require(balance0Before.add(amount0) <= balance0(), "M0");
        }
        if (amount1 > 0) {
            require(balance1Before.add(amount1) <= balance1(), "M1");
        }

        emit Mint(msg.sender, recipient, amount, amount0, amount1);
    }

    function collect(address recipient, uint128 amount0Requested, uint128 amount1Requested)
        external
        override
        returns (uint128 amount0, uint128 amount1)
    {
        Position storage position = positions[msg.sender];
        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit Collect(msg.sender, recipient, amount0, amount1);
    }

    function burn(uint128 amount) external override returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "Burn amount must be greater than 0");
        require(amount <= positions[msg.sender].liquidity, "Burn amount exceeds liquidity");
        // 修改 positions 中的信息
        (int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,
                /**
                 * @dev 这里 msg.sender 应该是 PositionManager 合约的地址? 这样如何区分呢?
                 */
                liquidityDelta: -int128(amount) // 负值
            })
        );
        // 获取燃烧后的 amount0 和 amount1
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (positions[msg.sender].tokensOwed0, positions[msg.sender].tokensOwed1) = (
                positions[msg.sender].tokensOwed0 + uint128(amount0),
                positions[msg.sender].tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, amount, amount0, amount1);
    }

    struct SwapState {
        // 剩余待交换的金额, 在交换过程中动态更新，用来追踪尚未完成的交换数量。两种方向的交易都可以追踪
        int256 amountSpecifiedRemaining;
        // 表示已经完成的交换量（已转入或已转出的数量）, 在从 token0 到 token1 的交易中，amountCalculated 就是已从池中交换出的 token1 数量，或者已从用户转出的 token0 数量。
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // 该交易中用户转入的 token0 的数量  (不一定是 token0 吧?)
        uint256 amountIn;
        // 该交易中用户转出的 token1 的数量
        uint256 amountOut;
        // 该交易中的手续费，如果 zeroForOne 是 ture，则是用户转入 token0，单位是 token0 的数量，反之是 token1 的数量
        uint256 feeAmount;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0, "AS");

        /**
         * @dev 价格始终指的是 token1 相对于 token0 的数量比例, p = x/y; sqrtPriceX96 = 根号p * 2^96
         * @dev 核心就是 token0 -> token1 时, 用户希望 p 小; token1 -> token0 时, 用户希望 p 大; 所以这样校验区间
         * @param sqrtPriceX96：当前池子的平方根价格。
         * @param sqrtPriceLimitX96：用户提供的价格限制。
         */
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE
                : sqrtPriceLimitX96 > sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE,
            "SPL"
        );

        bool exactInput = amountSpecified > 0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: sqrtPriceX96,
            feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            amountIn: 0,
            amountOut: 0,
            feeAmount: 0
        });

        uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(tickUpper);
        uint160 sqrtPriceX96PoolLimit = zeroForOne ? sqrtPriceX96Lower : sqrtPriceX96Upper;

        /**
         * @dev 传入当前价格、限制价格、流动性数量、交易量和手续费
         * @dev 返回交易后新的价格, 可以交易的数量，以及手续费
         */
        (state.sqrtPriceX96, state.amountIn, state.amountOut, state.feeAmount) = SwapMath.computeSwapStep(
            sqrtPriceX96,
            /**
             * token0 -> token1: 看pool价格限制是否小于用户价格限制, 如果是的话, 就选用户价格限制, 否则选pool价格限制
             * token1 -> token0: 看pool价格限制是否大于用户价格限制, 如果是的话, 就选用户价格限制, 否则选pool价格限制
             */
            (zeroForOne ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96 : sqrtPriceX96PoolLimit > sqrtPriceLimitX96)
                ? sqrtPriceLimitX96
                : sqrtPriceX96PoolLimit,
            liquidity,
            amountSpecified,
            fee
        );

        sqrtPriceX96 = state.sqrtPriceX96;
        tick = TickMath.getTickAtSqrtPrice(state.sqrtPriceX96);

        state.feeGrowthGlobalX128 += FullMath.mulDiv(state.feeAmount, FixedPoint128.Q128, liquidity);

        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        /**
         * 下面的注释以 token0 -> token1 为例子推演
         */
        if (exactInput) {
            // 指定了精确的 token0 输入
            state.amountSpecifiedRemaining -= (state.amountIn + state.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(state.amountOut.toInt256());
        } else {
            state.amountSpecifiedRemaining += state.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add((state.amountIn + state.feeAmount).toInt256());
        }

        /**
         * @dev 若 == 成立, 有两种情况:
         * @dev 1. token0 -> token1 && 精确输入;  2. token1 -> token0 && 精确输出
         * @dev 若 == 不成立, 也有两种情况:
         * @dev 1. token0 -> token1 && 精确输出;  2. token1 -> token0 && 精确输入
         * @dev 下面的注释以 == 成立时第一种情况来推算
         */
        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        if (zeroForOne) {
            // callback 中需要给 Pool 转入 token
            uint256 balance0Before = balance0();
            ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
            require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");

            // 转 Token 给用户
            if (amount1 < 0) {
                TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));
            }
        } else {
            // callback 中需要给 Pool 转入 token
            uint256 balance1Before = balance1();
            ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");

            // 转 Token 给用户
            if (amount0 < 0) {
                TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));
            }
        }

        emit Swap(msg.sender, recipient, amount0, amount1, sqrtPriceX96, liquidity, tick);
    }

    function getPosition(address owner)
        external
        view
        override
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        return (
            positions[owner].liquidity,
            positions[owner].feeGrowthInside0LastX128,
            positions[owner].feeGrowthInside1LastX128,
            positions[owner].tokensOwed0,
            positions[owner].tokensOwed1
        );
    }
}
