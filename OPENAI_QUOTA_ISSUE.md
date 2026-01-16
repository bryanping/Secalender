# OpenAI API 配额超限问题解决方案

## 错误信息

```
❌ OpenAI API错误: You exceeded your current quota
```

这是一个 **HTTP 429** 错误，表示 API 配额已用完。

## 问题原因

1. **API Key 的额度已用完**
   - 免费额度（$5）已用尽
   - 或付费额度已用完

2. **账户未绑定付款方式**
   - 免费额度用完后，需要绑定付款方式才能继续使用

3. **请求过于频繁**
   - 虽然这里是配额问题，但也可能是速率限制

## 解决方案

### 方案 1：检查账户余额（推荐）

1. 访问 OpenAI 账户页面：
   https://platform.openai.com/account/billing

2. 查看：
   - **Usage**：查看使用量
   - **Billing**：查看账单和余额
   - **Payment methods**：检查付款方式

3. 如果余额不足，需要：
   - 绑定付款方式（信用卡）
   - 充值账户

### 方案 2：更换 API Key

1. 生成新的 API Key：
   https://platform.openai.com/api-keys

2. 更新 `Secrets.xcconfig` 中的 `OPENAI_API_KEY`

3. 重新构建项目

### 方案 3：降低使用频率

如果配额充足但仍遇到错误：

1. 检查是否是速率限制（Rate Limit）
2. 减少 API 调用频率
3. 使用缓存机制（暂未实现）

### 方案 4：使用更便宜的模型（临时方案）

可以临时改用 `gpt-3.5-turbo` 降低成本：

```swift
// 在 OpenAIManager.swift 中修改
"model": "gpt-3.5-turbo",  // 更便宜，但质量较低
// 或
"model": "gpt-4o-mini",    // gpt-4o 的轻量版，更便宜
```

## 成本估算

### gpt-4o（当前使用）
- **输入**：$2.50 / 1M tokens
- **输出**：$10.00 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.0025)
  - 输出：~3000 tokens ($0.03)
  - **总计：约 $0.03-0.04**

### gpt-3.5-turbo（备选）
- **输入**：$0.50 / 1M tokens
- **输出**：$1.50 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.0005)
  - 输出：~3000 tokens ($0.0045)
  - **总计：约 $0.005**

### gpt-4o-mini（推荐折中方案）
- **输入**：$0.15 / 1M tokens
- **输出**：$0.60 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.00015)
  - 输出：~3000 tokens ($0.0018)
  - **总计：约 $0.002**

## 快速检查步骤

1. ✅ **检查 API Key 是否配置正确**
   - 打开 `Config/Secrets.xcconfig`
   - 确认 `OPENAI_API_KEY` 有值

2. ✅ **检查账户余额**
   - 访问：https://platform.openai.com/account/billing
   - 查看是否有可用余额

3. ✅ **检查付款方式**
   - 如果使用付费额度，确认已绑定付款方式

4. ✅ **检查使用量**
   - 查看 Usage 页面，了解使用情况

## 临时解决方案（如果配额已用完）

如果暂时无法充值，可以考虑：

1. **使用其他 API Key**（如果有多个账户）
2. **等待配额重置**（如果是免费额度，可能每月重置）
3. **暂时使用基础生成器**（质量较低，但可以工作）

## 预防措施

1. **设置使用限制**：在 OpenAI 账户中设置使用限额
2. **监控使用量**：定期检查使用情况
3. **使用更便宜的模型**：对于简单场景，使用 `gpt-3.5-turbo` 或 `gpt-4o-mini`
4. **实现缓存机制**：避免重复生成相同行程

## 相关链接

- OpenAI 账户页面：https://platform.openai.com/account
- 账单页面：https://platform.openai.com/account/billing
- API Keys：https://platform.openai.com/api-keys
- 使用量统计：https://platform.openai.com/usage
- 错误代码文档：https://platform.openai.com/docs/guides/error-codes
