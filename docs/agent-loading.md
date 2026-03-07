# Agent 加载机制说明

本项目 agent 加载机制采用双源模式：内置 agent 与用户自定义 agent 结合。

## 1. Agent 来源

### 1.1 内置 Agent (Native Agents)

内置 agent 在 [`packages/opencode/src/agent/agent.ts`](packages/opencode/src/agent/agent.ts) 的 `Agent.state()` 函数中定义，包含以下几种：

| Agent 名称 | 模式 | 说明 |
|------------|------|------|
| `build` | primary | 默认 agent，根据配置的权限执行工具 |
| `plan` | primary | 计划模式，禁止所有编辑工具 |
| `general` | subagent | 通用 agent，用于研究和执行多步骤任务 |
| `explore` | subagent | 快速探索代码库的专业 agent |
| `compaction` | primary | 压缩模式（隐藏） |
| `title` | primary | 标题生成（隐藏） |
| `summary` | primary | 摘要生成（隐藏） |

### 1.2 用户自定义 Agent

用户可通过在项目根目录下的 `.opencode/agent/` 或 `.opencode/agents/` 目录中添加 markdown 文件来定义自定义 agent。

扫描模式：`{agent,agents}/**/*.md`

#### 目录结构示例

```
.opencode/
├── agents/
│   ├── helper.md          # agent name: "helper"
│   └── nested/
│       └── child.md       # agent name: "nested/child"
```

#### 文件格式

```markdown
---
model: openai/gpt-4o
mode: subagent
temperature: 0.7
description: 这是一个帮助 agent
permission:
  read: allow
  write: ask
---

这里是 agent 的系统 prompt 内容
```

**支持的 Frontmatter 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `model` | string | 模型 ID (如 `openai/gpt-4o`) |
| `mode` | string | 模式：`subagent`、`primary`、`all` |
| `temperature` | number | 温度参数 |
| `top_p` | number | top_p 参数 |
| `variant` | string | 模型变体 |
| `description` | string | agent 描述 |
| `color` | string | 颜色（hex 或 theme 颜色名） |
| `steps` | number | 最大迭代次数 |
| `hidden` | boolean | 是否在 @ 自动补全中隐藏 |
| `disable` | boolean | 禁用内置 agent |
| `permission` | object | 权限规则 |
| `options` | object | 扩展选项 |

## 2. 加载流程

### 2.1 配置文件解析

在 [`packages/opencode/src/config/config.ts`](packages/opencode/src/config/config.ts:396) 的 `loadAgent` 函数中完成：

```typescript
async function loadAgent(dir: string) {
  const result: Record<string, Agent> = {}
  
  // 扫描 {agent,agents}/**/*.md
  for (const item of await Glob.scan("{agent,agents}/**/*.md", { cwd: dir })) {
    const md = await ConfigMarkdown.parse(item)
    // 文件名作为 agent 名称
    const file = rel(item, patterns) ?? path.basename(item)
    const agentName = trim(file)
    
    const config = {
      name: agentName,
      ...md.data,
      prompt: md.content.trim(),
    }
  }
  return result
}
```

### 2.2 Agent 合并逻辑

在 [`packages/opencode/src/agent/agent.ts`](packages/opencode/src/agent/agent.ts:205) 中，用户自定义 agent 会与内置 agent 合并：

```typescript
for (const [key, value] of Object.entries(cfg.agent ?? {})) {
  if (value.disable) {
    delete result[key]  // 禁用内置 agent
    continue
  }
  // 合并配置到内置 agent 或创建新 agent
}
```

优先级：**用户配置 > 内置配置**

## 3. Agent 结构

Agent 信息在运行时转换为 `Agent.Info` 类型：

```typescript
export const Info = z.object({
  name: z.string(),
  description: z.string().optional(),
  mode: z.enum(["subagent", "primary", "all"]),
  native: z.boolean().optional(),
  hidden: z.boolean().optional(),
  topP: z.number().optional(),
  temperature: z.number().optional(),
  color: z.string().optional(),
  permission: PermissionNext.Ruleset,
  model: z.object({ modelID: z.string(), providerID: z.string() }).optional(),
  variant: z.string().optional(),
  prompt: z.string().optional(),
  options: z.record(z.string(), z.any()),
  steps: z.number().int().positive().optional(),
})
```

## 4. 使用 API

```typescript
import { Agent } from "@/agent"

// 获取单个 agent
const agent = await Agent.get("explore")

// 列出所有 agent
const agents = await Agent.list()

// 获取默认 agent
const defaultAgent = await Agent.defaultAgent()
```

## 5. 权限机制

Agent 使用 [`PermissionNext`](packages/opencode/src/permission/next.ts) 进行权限管理，权限可以按工具类型配置为：

- `allow`：允许
- `deny`：拒绝
- `ask`：询问用户

示例：

```yaml
permission:
  read: allow
  write: ask
  bash: deny
  external_directory:
    "*": ask
    "/path/to/allowed": allow