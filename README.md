# Miniswap
## 设计思路
自顶向下的五个合约：
1. PoolManager.sol: 顶层合约，对应 Pool 页面，负责 Pool 的创建和管理(这个能力继承自 Factory)。还给 DApp 提供获取所有交易池信息的接口，这样的接口可以通过服务端来提供，它并不是必须的。
2. PositionManager.sol: 顶层合约，对应 Position 页面，负责 LP 头寸和流动性的管理；
3. SwapRouter.sol: 顶层合约，对应 Swap 页面，负责预估价格和交易；用户也可以直接操作 pool，但是每个 pair 对应多个 pool，使用 router 更加安全高效便利。在 Uniswap 中可以 多跳交换，此处为了简化暂时不支持，**后续支持**。本项目先实现择不同的价格区间的交易池（选择对用户最优的价格，一个池子不够就部分成交后选下一个池子，还不满足用户要求的 amount 就只实现部分成交）。
4. Factory.sol: 底层合约，Pool 的工厂合约；由 PoolManager 继承, 不需要单独部署.
5. Pool.sol: 最底层合约，对应一个交易池，记录了当前价格、头寸、流动性等信息。由 PoolManager 管理, 不需要单独部署

