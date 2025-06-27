<div align="center">
  <img src="images/ntt-logo.png">
</div>

---

# 概述

这是一个基于 Wormhole 原生代币传输（NTT）框架实现自定义 Payload 的示例项目。Wormhole NTT 是一个开放、灵活且可组合的框架，用于在无需流动性池的情况下跨区块链传输代币。集成商可以完全控制其原生传输代币（NTT）在每个链上的行为，包括代币标准和元数据。

对于现有的代币部署，该框架可以在"锁定"模式下使用，在单个链上保持原始代币供应。或者，该框架可以在"销毁"模式下使用，部署原生多链代币，供应量分布在多个链之间。

## 设计架构

NTT 有两个基本组件：

(1) **Transceiver（收发器）**：该合约负责发送通过源链上的 `NttManager` 转发的 NTT 传输，并传递到目标链上相应的对等 `NttManager`。收发器应遵循 `ITransceiver` 接口。收发器可以独立于 Wormhole 核心定义，并且可以修改以支持任何验证后端。更多信息请参见 [docs/Transceiver.md](./docs/Transceiver.md)。

(2) **NttManager（NTT 管理器）**：NttManager 合约负责管理代币和收发器。它还处理速率限制和消息认证逻辑。请注意，每个 `NttManager` 对应单个代币。但是，单个 `NttManager` 可以控制多个收发器。更多信息请参见 [docs/NttManager.md](./docs/NttManager.md)。

<figure>
  <img src="images/ntt-payload.jpg" alt="NTT 架构图">
  <figcaption>图：带有自定义认证的 NTT 架构图</figcaption>
</figure>

## 自定义 Payload 支持

NTT 框架的一个重要特性是支持自定义 Payload，允许开发者在跨链传输中添加额外的数据：

- **源链**：在 `_prepareNativeTokenTransfer` 中可以构造包含自定义数据的 Payload
- **目标链**：在 `_handleAdditionalPayload` 中可以解析和处理自定义数据

这种设计使得 NTT 不仅支持简单的代币传输，还可以实现复杂的跨链应用场景.通过携带一段自定义 Payload, 在目标链自动触发智能合约逻辑，比如：
- 写入链上事件日志；
- 调用合约函数，如发放徽章、积分结算、NFT 铸造；
- 甚至组合复杂逻辑，如任务判定 + 状态更新。

### 源链上 NttManager 的执行流程

当用户在源链上发起跨链时,调用 `transfer` 函数，NttManager 会按以下流程执行：

```
transfer
  └─▶ _transferEntryPoint  ← 🔥 销毁或锁定 Token
       ├─▶ _transfer                 
			└─▶├─▶ _prepareNativeTokenTransfer ← ✨ 构造跨链 Payload（支持自定义）
		       ├─▶ _sendMessageToTransceivers  ← 🚀 由 Transceiver 转发给 Wormhole 网络广播
```

**详细说明：**

1. **transfer**：用户调用的入口函数，指定目标链、接收地址和转账金额等信息
2. **_transferEntryPoint**：根据配置的模式（锁定/销毁）处理代币：
   - **Locking 模式**：锁定用户的代币
   - **Burning 模式**：销毁用户的代币
3. **_transfer**：执行核心转账逻辑
4. **_prepareNativeTokenTransfer**：构造跨链消息的 Payload，这是自定义 Payload 的关键环节
5. **_sendMessageToTransceivers**：将消息发送给所有注册的收发器
6. **Transceiver**：接收消息并通过 Wormhole 网络广播到目标链

### 目标链上 NttManager 的执行流程

当 Wormhole 网络将消息传递到目标链时，Wormhole 的 Relayer 会调用 Transceiver 合约,并最终触发 NttManager 合约执行以下流程：

```
executeMsg ─▶ _handleMsg ─▶ _handleTransfer├─▶ _handleAdditionalPayload
                                           └─▶ _mintOrUnlockToRecipient
```

**详细说明：**
1. **executeMsg**：接收来自 Wormhole 网络的消息
2. **_handleMsg**：验证消息的有效性和来源
3. **_handleTransfer**：处理转账相关的核心逻辑
4. **_handleAdditionalPayload**：处理自定义 Payload 数据，这是实现自定义功能的关键环节
5. **_mintOrUnlockToRecipient**：根据配置的模式处理代币：
   - **Locking 模式**：在目标链铸造新代币给接收者
   - **Burning 模式**：在目标链铸造新代币给接收者



## 快速开始

### 完整部署流程

#### 步骤 1: OP Sepolia 部署 NTT Token

```bash
# 克隆示例代币项目
git clone https://github.com/wormhole-foundation/example-ntt-token.git
cd example-ntt-token

# 设置环境变量
export HACKQUEST=0xAe3759Ccc3E0877fFBb4d533a88Bf9AD0F2Df3F8
export OP_PRIVATE_KEY=0xyour_private_key

# 部署代币合约
forge create --rpc-url "https://sepolia.optimism.io" \
  --private-key $OP_PRIVATE_KEY \
  --broadcast src/PeerToken.sol:PeerToken \
  --constructor-args "HackQuest" "HQ" $HACKQUEST $HACKQUEST

# 记录代币地址
export OP_TOKEN_ADDRESS=0x0dc19A2257523E77789e4D6201722C7e382030E7
```

#### 步骤 2: 铸造代币

```bash
# 铸造 1000 枚代币
cast send --private-key $OP_PRIVATE_KEY \
  --rpc-url "https://sepolia.optimism.io" \
  $OP_TOKEN_ADDRESS \
  "mint(address,uint256)" \
  $HACKQUEST \
  1000000000000000000000

# 验证余额
cast call $OP_TOKEN_ADDRESS "balanceOf(address)(uint256)" $HACKQUEST \
  --rpc-url "https://sepolia.optimism.io"
```

#### 步骤 3: 初始化 NTT 项目

```bash
# 创建新的 NTT 项目
ntt new ntt-custom-payload
cd ntt-custom-payload

# 初始化测试网配置
ntt init Testnet

# 安装 Foundry 依赖
forge install
```

#### 步骤 4: 修改 NttManager 合约

需要修改以下两个关键函数来支持自定义 Payload(具体参考课程第 5、6 单元内容):

**源链 NttManager 合约**：
- 修改 `_prepareNativeTokenTransfer` 函数，构建自定义 Payload

**目标链 NttManager 合约**：
- 修改 `_handleAdditionalPayload` 函数，解析并处理自定义 Payload

#### 步骤 5: 修改部署脚本

修改 NTT 项目的部署脚本, 位于 `evm/script`，支持部署自定义 Payload 的 NTT 合约(具体参考课程第 7、8单元)。

#### 步骤 6: 添加源链（Optimism Sepolia）

```bash
# 设置环境变量
export ETH_PRIVATE_KEY=0xyour_private_key
export OPTIMISMSEPOLIA_SCAN_API_KEY=your_scan_api_key
export OP_TOKEN_ADDRESS=0x0dc19A2257523E77789e4D6201722C7e382030E7

# 添加链到部署配置
ntt add-chain OptimismSepolia --local --mode burning --token $OP_TOKEN_ADDRESS

# 记录 Manager 地址
export NTT_MANAGER_ADDRESS=0x3e1A1A9Fa0F1F15B4D0f58d60e5358B81b385981
```

#### 步骤 7: 配置代币铸造权限

```bash
# 设置 NTT Manager 为代币铸造者
cast send $OP_TOKEN_ADDRESS "setMinter(address)" $NTT_MANAGER_ADDRESS \
  --private-key $OP_PRIVATE_KEY \
  --rpc-url "https://sepolia.optimism.io"
```

#### 步骤 8: 部署目标链 ERC20 合约

```bash
# 在目标链（Arbitrum Sepolia）部署代币
git clone https://github.com/wormhole-foundation/example-ntt-token.git
cd example-ntt-token

export HACKQUEST=0xAe3759Ccc3E0877fFBb4d533a88Bf9AD0F2Df3F8
export ARB_PRIVATE_KEY=0xyour_private_key

forge create --rpc-url "https://sepolia-rollup.arbitrum.io/rpc" \
  --private-key $ARB_PRIVATE_KEY \
  --broadcast src/PeerToken.sol:PeerToken \
  --constructor-args "HackQuest" "HQ" $HACKQUEST $HACKQUEST

# 记录目标链代币地址
export ARB_TOKEN_ADDRESS=0xd3DbA4E5cB7c31302ce1FEB95066538Db3061EdC
```

#### 步骤 9: 添加目标链（Arbitrum Sepolia）

```bash
# 设置环境变量
export ETH_PRIVATE_KEY=0xyour_private_key
export ARBITRUMSEPOLIA_SCAN_API_KEY=your_scan_api_key
export ARB_TOKEN_ADDRESS=0xC2234C848e65200507d06245109b7e491679228E

# 添加目标链
ntt add-chain ArbitrumSepolia --local --mode burning --token $ARB_TOKEN_ADDRESS

# 记录目标链 Manager 地址
export NTT_MANAGER_ADDRESS=0x25395e7A736DBd38894Bf424B192793c07aE51aF
```

#### 步骤 10: 配置目标链代币铸造权限

```bash
# 设置目标链 NTT Manager 为代币铸造者
cast send $ARB_TOKEN_ADDRESS "setMinter(address)" $NTT_MANAGER_ADDRESS \
  --private-key $ARB_PRIVATE_KEY \
  --rpc-url "https://sepolia-rollup.arbitrum.io/rpc"
```

#### 步骤 11: 配置 NTT 网络

```bash
# 拉取当前配置
ntt pull

# 修改 inbound 和 outbound 限制配置
# 编辑 deployment.json 文件，调整传输限制

# 推送配置到区块链
ntt push
```

#### 步骤 12: 启动前端界面

```bash
# 克隆前端项目
git clone https://github.com/wormhole-foundation/demo-ntt-connect.git
cd demo-ntt-connect

# 安装依赖
npm install

# 修改 App.tsx 中代币、区块链等配置

# 启动开发服务器
npm run dev
```

#### 步骤 13: 测试自定义 Payload

```bash
# 向源链自定义合约写入消息
export CUSTOM_PAYLOAD_CONTRACT=0x235c950CF529821d7F14f530bcD0ed63Ea71507F

cast send $CUSTOM_PAYLOAD_CONTRACT "setBlessMessage(string)" "GM, NTT Custom Payload" \
  --private-key $OP_PRIVATE_KEY \
  --rpc-url "https://sepolia.optimism.io"
```

## 部署示例

项目包含以下示例交易：

**源链交易（Optimism Sepolia）**：
- https://sepolia-optimism.etherscan.io/tx/0x1dfbed30fd89fe215ce88ce722a421949fc6cfbc768ac66fc8f22d986b69d46a#eventlog

**目标链交易（Arbitrum Sepolia）**：
- https://sepolia.arbiscan.io/tx/0x98ded06ab95ad09a4ff2087ae7ef1d40d993392fff8a1adccd05971854a9e038#eventlog

**Wormhole 扫描**：
- https://wormholescan.io/#/tx/0x1dfbed30fd89fe215ce88ce722a421949fc6cfbc768ac66fc8f22d986b69d46a?network=Testnet&view=advanced