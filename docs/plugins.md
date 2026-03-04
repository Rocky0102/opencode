# OpenCode 插件系统说明文档

本文档介绍 `packages/opencode/src/plugin` 目录下的插件系统及其各个插件的功能。

## 目录

- [插件系统概述](#插件系统概述)
- [内置插件](#内置插件)
  - [Codex 认证插件](#codex-认证插件-codexts)
  - [GitHub Copilot 认证插件](#github-copilot-认证插件-copilotts)
- [插件系统架构](#插件系统架构)

---

## 插件系统概述

OpenCode 的插件系统允许用户扩展和定制 OpenCode 的功能。插件系统位于 [`index.ts`](packages/opencode/src/plugin/index.ts) 文件中，负责：

1. **加载内置插件**：直接导入并初始化内置插件（如 Codex、Copilot、GitLab 认证插件）
2. **安装和加载外部插件**：从 npm 安装并加载用户配置的外部插件
3. **管理插件钩子（Hooks）**：收集和触发插件定义的各种钩子函数
4. **事件订阅**：将系统事件分发给所有插件

### 内置插件列表

```typescript
const INTERNAL_PLUGINS: PluginInstance[] = [
  CodexAuthPlugin,      // OpenAI Codex 认证
  CopilotAuthPlugin,    // GitHub Copilot 认证
  GitlabAuthPlugin      // GitLab 认证
]
```

### 默认外部插件

```typescript
const BUILTIN = ["opencode-anthropic-auth@0.0.13"]
```

---

## 内置插件

### Codex 认证插件 ([`codex.ts`](packages/opencode/src/plugin/codex.ts))

#### 功能概述

Codex 认证插件为 OpenCode 提供 OpenAI Codex API 的身份验证支持。它允许用户通过 ChatGPT Pro/Plus 订阅访问 Codex 系列模型。

#### 支持的模型

该插件会过滤并只允许访问以下 Codex 模型：

| 模型 ID | 描述 |
|---------|------|
| `gpt-5.1-codex-max` | GPT-5.1 Codex Max |
| `gpt-5.1-codex-mini` | GPT-5.1 Codex Mini |
| `gpt-5.2` | GPT-5.2 |
| `gpt-5.2-codex` | GPT-5.2 Codex |
| `gpt-5.3-codex` | GPT-5.3 Codex（默认模型） |
| `gpt-5.1-codex` | GPT-5.1 Codex |

#### 认证方式

插件提供三种认证方式：

##### 1. 浏览器 OAuth 认证（ChatGPT Pro/Plus）

```
标签：ChatGPT Pro/Plus (browser)
类型：OAuth
```

**工作流程：**
1. 在本地启动 OAuth 回调服务器（端口 1455）
2. 生成 PKCE（Proof Key for Code Exchange）验证码和状态码
3. 构建授权 URL 并引导用户在浏览器中完成授权
4. 用户授权后，回调服务器接收授权码
5. 使用授权码交换访问令牌和刷新令牌
6. 自动关闭回调服务器

**OAuth 配置：**
- 客户端 ID：`app_EMoamEEZ73f0CkXaXp7hrann`
- 授权端点：`https://auth.openai.com/oauth/authorize`
- 令牌端点：`https://auth.openai.com/oauth/token`
- 回调地址：`http://localhost:1455/auth/callback`
- 作用域：`openid profile email offline_access`

##### 2. 无头设备认证（ChatGPT Pro/Plus）

```
标签：ChatGPT Pro/Plus (headless)
类型：OAuth
```

**工作流程：**
1. 向 `https://auth.openai.com/api/accounts/deviceauth/usercode` 请求设备码
2. 显示验证 URL 和用户码：`https://auth.openai.com/codex/device`
3. 轮询 `https://auth.openai.com/api/accounts/deviceauth/token` 检查授权状态
4. 授权成功后获取令牌

##### 3. API 密钥手动输入

```
标签：Manually enter API Key
类型：API
```

用户可以直接输入 OpenAI API 密钥进行认证。

#### 令牌管理

- **自动刷新**：当访问令牌过期时，自动使用刷新令牌获取新的访问令牌
- **账户 ID 提取**：从 JWT 令牌中提取 `chatgpt_account_id` 或组织 ID
- **成本归零**：Codex 模型的费用显示为零（包含在 ChatGPT 订阅中）

#### 请求拦截

插件会拦截发往 OpenAI 的请求并：

1. 移除虚拟 API 密钥的 Authorization 头
2. 添加 Bearer 令牌进行认证
3. 设置 `ChatGPT-Account-Id` 头（用于组织订阅）
4. 将请求 URL 重写到 Codex 端点：`https://chatgpt.com/backend-api/codex/responses`

#### 请求头注入

为所有 Codex 请求添加以下头信息：

```typescript
{
  "originator": "opencode",
  "User-Agent": `opencode/${VERSION} (${platform} ${release}; ${arch})`,
  "session_id": sessionID
}
```

---

### GitHub Copilot 认证插件 ([`copilot.ts`](packages/opencode/src/plugin/copilot.ts))

#### 功能概述

GitHub Copilot 认证插件为 OpenCode 提供 GitHub Copilot API 的身份验证支持。它允许用户通过 GitHub Copilot 订阅访问各种 AI 模型。

#### 支持的部署类型

- **GitHub.com**：公共 GitHub 部署
- **GitHub Enterprise**：企业级部署（支持数据驻留或自托管）

#### 认证方式

##### OAuth 设备授权流程

```
标签：Login with GitHub Copilot
类型：OAuth
```

**工作流程：**

1. **选择部署类型**：用户选择 GitHub.com 或 GitHub Enterprise
2. **输入企业 URL**（仅企业部署）：用户输入企业 GitHub URL 或域名
3. **设备码获取**：向 GitHub 请求设备授权码
   - GitHub.com：`https://github.com/login/device/code`
   - GitHub Enterprise：`https://{domain}/login/device/code`
4. **用户验证**：用户访问验证 URL 并输入设备码
5. **令牌轮询**：自动轮询令牌端点等待授权完成
   - GitHub.com：`https://github.com/login/oauth/access_token`
   - GitHub Enterprise：`https://{domain}/login/oauth/access_token`

**OAuth 配置：**
- 客户端 ID：`Ov23li8tweQw6odWQebz`
- 作用域：`read:user`

#### 认证提示配置

```typescript
prompts: [
  {
    type: "select",
    key: "deploymentType",
    message: "Select GitHub deployment type",
    options: [
      { label: "GitHub.com", value: "github.com", hint: "Public" },
      { label: "GitHub Enterprise", value: "enterprise", hint: "Data residency or self-hosted" }
    ]
  },
  {
    type: "text",
    key: "enterpriseUrl",
    message: "Enter your GitHub Enterprise URL or domain",
    placeholder: "company.ghe.com or https://company.ghe.com",
    condition: (inputs) => inputs.deploymentType === "enterprise"
  }
]
```

#### 请求拦截

插件会拦截所有发往 GitHub Copilot 的请求并：

1. **设置认证头**：
   ```typescript
   {
     "Authorization": `Bearer ${accessToken}`,
     "x-initiator": isAgent ? "agent" : "user",
     "User-Agent": `opencode/${VERSION}`,
     "Openai-Intent": "conversation-edits"
   }
   ```

2. **视觉请求处理**：
   - 检测请求是否包含图像内容（`isVision`）
   - 为视觉请求添加 `Copilot-Vision-Request: true` 头

3. **代理会话标记**：
   - 检测子代理会话（`parentID` 存在）
   - 将子代理会话的 `x-initiator` 设置为 `agent`

#### 成本处理

所有 GitHub Copilot 模型的成本都被设置为零，因为费用已包含在 Copilot 订阅中：

```typescript
model.cost = {
  input: 0,
  output: 0,
  cache: { read: 0, write: 0 }
}
```

#### 域名标准化

```typescript
function normalizeDomain(url: string) {
  return url.replace(/^https?:\/\//, "").replace(/\/$/, "")
}
```

将用户输入的 URL 或域名标准化为裸域名格式。

#### 企业部署 URL 构建

```typescript
const baseURL = enterpriseUrl 
  ? `https://copilot-api.${normalizeDomain(enterpriseUrl)}` 
  : undefined
```

---

## 插件系统架构

### 核心接口

#### PluginInput

插件初始化时接收的输入参数：

```typescript
interface PluginInput {
  client: OpenCodeClient    // OpenCode API 客户端
  project: string            // 项目名称
  worktree: string           // 工作树名称
  directory: string          // 工作目录
  serverUrl: string          // 服务器 URL
  $: Bun.$                   // Bun shell 命令执行器
}
```

#### Hooks

插件可以实现的钩子函数：

```typescript
interface Hooks {
  // 配置钩子 - 在配置加载时调用
  config?: (config: Config) => Promise<void>
  
  // 认证钩子 - 定义认证提供者
  auth?: {
    provider: string
    loader: (getAuth, provider) => Promise<AuthResult>
    methods: AuthMethod[]
  }
  
  // 聊天头信息钩子 - 为聊天请求添加自定义头
  "chat.headers"?: (input, output) => Promise<void>
  
  // 事件钩子 - 订阅系统事件
  event?: (event: SystemEvent) => Promise<void>
}
```

### 插件加载流程

```
1. 初始化内部插件
   ├── CodexAuthPlugin
   ├── CopilotAuthPlugin
   └── GitlabAuthPlugin

2. 加载配置中的外部插件
   ├── 安装 npm 包（如未安装）
   └── 动态导入模块

3. 收集所有钩子函数
   └── 存储在 state.hooks 数组中

4. 触发插件初始化
   ├── 调用各插件的 config 钩子
   └── 订阅系统事件
```

### 插件通信

插件通过 [`Bus`](packages/opencode/src/bus) 系统订阅和发布事件：

```typescript
Bus.subscribeAll(async (input) => {
  const hooks = await state().then((x) => x.hooks)
  for (const hook of hooks) {
    hook["event"]?.({ event: input })
  }
})
```

### 错误处理

插件加载失败时会发布错误事件：

```typescript
Bus.publish(Session.Event.Error, {
  error: new NamedError.Unknown({
    message: `Failed to install/load plugin ${plugin}: ${detail}`
  }).toObject()
})
```

---

## 开发自定义插件

### 插件模板

```typescript
import type { Hooks, PluginInput } from "@opencode-ai/plugin"

export async function MyCustomPlugin(input: PluginInput): Promise<Hooks> {
  return {
    // 配置钩子
    async config(config) {
      // 处理配置
    },
    
    // 认证钩子
    auth: {
      provider: "my-provider",
      async loader(getAuth, provider) {
        const auth = await getAuth()
        // 返回认证配置
        return {
          apiKey: "...",
          async fetch(request, init) {
            // 自定义请求处理
            return fetch(request, init)
          }
        }
      },
      methods: [
        {
          label: "Login with My Provider",
          type: "oauth",
          async authorize() {
            // 实现授权流程
            return {
              url: "...",
              instructions: "...",
              method: "auto",
              async callback() {
                return { type: "success", refresh: "...", access: "...", expires: 0 }
              }
            }
          }
        }
      ]
    },
    
    // 聊天头信息钩子
    async "chat.headers"(input, output) {
      output.headers["X-Custom-Header"] = "value"
    }
  }
}
```

### 发布插件

1. 创建 npm 包，导出插件函数
2. 在 `opencode.config.ts` 中添加插件配置：

```typescript
export default {
  plugin: [
    "my-custom-plugin@1.0.0"
  ]
}
```

---

## 相关文件

- [`packages/opencode/src/plugin/index.ts`](packages/opencode/src/plugin/index.ts) - 插件系统主入口
- [`packages/opencode/src/plugin/codex.ts`](packages/opencode/src/plugin/codex.ts) - Codex 认证插件
- [`packages/opencode/src/plugin/copilot.ts`](packages/opencode/src/plugin/copilot.ts) - GitHub Copilot 认证插件
- [`@opencode-ai/plugin`](packages/plugin) - 插件类型定义
- [`@gitlab/opencode-gitlab-auth`](packages/gitlab) - GitLab 认证插件（外部包）

---

## 总结

OpenCode 的插件系统提供了灵活的扩展机制，允许：

1. **身份验证扩展**：支持多种 AI 服务提供商的认证方式
2. **请求拦截**：在请求发送前修改头信息、URL 等
3. **事件订阅**：监听和响应系统事件
4. **配置定制**：根据插件需求修改配置

内置的 Codex 和 Copilot 插件为用户提供了便捷的 AI 服务认证方案，让用户可以直接使用 ChatGPT 或 GitHub Copilot 订阅来访问 AI 模型，而无需单独购买 API 服务。