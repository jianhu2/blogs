---
title: "AI-Agent-OpenClaw架构与工作原理"
subtitle: ""
date: 2026-03-17T08:19:04+08:00
lastmod: "2026-03-18"
draft: false
image: "/images/openclaw_arch_overview.png"
tags: ["AI"]
hideFromHomePage: false
---
> 技术分享 · Agent 架构 · Tool Use 机制 · LLM
>

---

## 1. OpenClaw 架构
<!-- 这是一张图片，ocr 内容为： -->
![](/images/openclaw_arch_overview.png)
> 消息从 Channels 进入 Agent Runtime，由 Planner 驱动循环，Tools / Memory / LLM 均由 Planner 主动调用。
>

### 组件对照表
| 模块 | OpenClaw 组件 | 职责 |
| --- | --- | --- |
| **Channels** | Feishu / Telegram / CLI / UI | 消息入口，接收用户指令并返回结果 |
| **Agent Runtime** | gateway 核心代理 | 启动 Planner，监听任务完成信号，将最终结果写回 Channel |
| **Planner** | Agent Loop 的具体实现 | 规划任务步骤，驱动"LLM → tool_use → 执行 → 观察"循环 |
| **Tools** | exec / http / fs | 实际执行动作的原子能力 |
| **Memory** | workspace | 维护对话历史、tool_result，是两轮对话之间的纽带 |
| **LLM** | 模型 provider（kimi 等） | 推理与决策引擎，被 Planner 主动调用，只做推理不做执行 |


> **注意**：Planner 实现了 Agent Loop，Agent Loop 是 Planner 的运行机制。Tools 和 LLM 都由 Planner 在循环中主动调用，不由 Agent Runtime 直接驱动。
>

---

## 2. 各模块详解
### Channels — 消息入口层
用户与 openclaw 交互的渠道，支持多端接入：

+ **Feishu**：企业内部飞书机器人，最常见的生产环境接入方式
+ **Telegram**：面向个人用户或小团队的快速接入
+ **CLI**：命令行直接调用，适合开发调试和自动化脚本
+ **UI**：Web 聊天对话页面

> Channel 只负责收发消息，不参与任何业务逻辑，实现了接入层与业务层的解耦。
>

---

### Agent Runtime — 核心驱动
整个系统的调度中心，职责是：

1. 从 Channel 接收用户消息
2. **启动 Planner**，将消息交给 Agent Loop 处理
3. 监听 Planner 的完成信号
4. 将最终结果写回 Channel 展示给用户

> Agent Runtime **不直接调用** Tools 或 LLM。这两者都由 Planner 在循环内部驱动。
>

---

### Planner — 任务规划器（Agent Loop 的实现）
Planner 实现了 Agent Loop，是 openclaw 能自主执行多步骤任务的核心。每一轮循环包含完整的"推理 → 决策 → 执行 → 观察"链路：

<!-- 这是一张图片，ocr 内容为： -->
![](/images/openclaw_planner_loop.png)

> LLM 推理 → 判断是否需要工具 → 返回 tool_use block → Tool 执行 → tool_result 写入 Memory → 下一轮 LLM 输入；直到 LLM 判断任务完成，输出自然语言回答。
>

**关键特性**：

+ Planner 负责循环控制流（"推进"），LLM 负责每步推理（"想"）
+ tool_use block 是 LLM 发出的结构化指令，触发 Tool 执行
+ tool_result 写入 Memory 后才能被下一轮 LLM 读取，这是两轮对话的核心机制

---

### Tools — 原子执行层
Tools 是 openclaw 真正"干活"的地方，三类核心工具：

<!-- 这是一张图片，ocr 内容为： -->
![](/images/shell_file.png)

#### `exec/file_search` — shell 命令执行（本地）
+ 执行任意 bash / zsh / python 命令
+ 捕获 stdout / stderr
+ 超时检测 + 退出码处理

#### `http` — HTTP 请求（需联网）
+ 调用外部 REST / GraphQL API
+ 在线搜索（Brave Search / Tavily / SerpAPI / DuckDuckGo）
+ Webhook 触发

#### `fs` — 文件系统操作（本地）
+ 读取 / 写入 / 追加文件
+ glob / ripgrep 文件搜索
+ 创建 / 删除目录

---

### Memory — 工作区与上下文
Memory 是 Agent 的"工作台"，解决 LLM 无状态的核心问题：

| 类型 | 内容 | 作用 |
| --- | --- | --- |
| **对话历史** | 用户消息 + 历轮 LLM 回复 | 保持上下文连贯 |
| **tool_use block** | LLM 发出的工具调用指令 | 触发 Tool 执行的结构化指令，存入历史供追溯 |
| **tool_result** | Tools 执行后的原始输出 | **两轮对话之间的纽带**，喂回 LLM 做第二轮推理 |
| **workspace** | 任务中间产物（文件、变量） | 跨步骤共享数据 |


> **区分 tool_use block 与 tool_result**：tool_use block 是"LLM 发出的指令"，是第一轮的产物；tool_result 是"Tool 执行后的结果"，是两轮之间真正的传递载体。
>

---

### LLM — 推理与决策引擎
LLM 是整个系统的大脑，**只做推理，不做执行**，由 Planner 在每轮循环中主动调用：

```plain
输入：对话历史 + tools 定义 + 当前 Memory（含 tool_result）
    │
    ▼
LLM 推理
    │
    ├─ 情况A：直接回答 ──▶ 返回自然语言文字（任务完成）
    └─ 情况B：需要工具 ──▶ 返回 tool_use block（结构化调用指令）
```

openclaw 支持多种 LLM provider，通过配置切换：kimi、GPT-4、Claude、本地模型等。

---

## 3. 完整工作流程（两轮对话）
<!-- 这是一张图片，ocr 内容为： -->
![](/images/openclaw_two_round_flow.png)

> 第一轮：gateway 将用户消息 + tools 定义发给 LLM，LLM 返回 tool_use block，Planner 解析后执行 Tool，结果写入 Memory。第二轮：gateway 将对话历史 + tool_result 再次发给 LLM，LLM 生成自然语言回答返回给用户。
>

> **核心原则**：Tools 执行的原始输出不直接给用户，必须经 LLM 第二次推理后才返回。Memory 中的 tool_result 是两轮之间的纽带。
>

---

## 4. Tools · Skills · Agent 三层类比
> LLM = 大脑 · Tools = 手的动作 · Skills = 习得技能 · Agent = 整个人
>

<!-- 这是一张图片，ocr 内容为： -->
![](/images/agent-tools.png)

| 概念 | 类比 | 本质 |
| --- | --- | --- |
| **Tools** | 按键、抬手 | 原子动作，每个只做一件事，不知道为什么做 |
| **Skills** | 弹钢琴 | 对 Tools 的预定义编排（固定顺序和组合），例如"搜索 + 总结"是一个 Skill |
| **Agent** | 整个工程师 | 自主循环直到任务完成，会规划、会判断 |


> **说明**：Skills 是预定义的多步骤工作流，与 Tools 的区别在于它知道顺序和目的；而 Agent（Planner）是在运行时由 LLM 动态决定如何组合 Tools，不受固定编排限制。
>

---

## 5. 总结
**openclaw = 一个完整的 AI Agent**

| # | 要点 | 说明 |
| --- | --- | --- |
| 01 | **多渠道接入** | Feishu / Telegram / CLI / UI，接入层与业务层解耦 |
| 02 | **Agent Runtime 只是调度器** | 启动 Planner、监听完成、写回 Channel；循环逻辑在 Planner 内 |
| 03 | **Planner 实现 Agent Loop** | 驱动"LLM 推理 → tool_use → Tool 执行 → tool_result → 下一轮"循环 |
| 04 | **两轮对话完成任务** | 第一轮 LLM 决策并发出 tool_use block，第二轮 LLM 读取 tool_result 生成回答 |
| 05 | **Memory 是两轮之间的纽带** | tool_result 经 Memory 传递，LLM 才能在第二轮理解执行结果 |
| 06 | **LLM 只做推理** | 真正执行在 Tools（exec / http / fs），LLM 不直接操作环境 |
| 07 | **工具可插拔** | Tools 和 LLM provider 均可通过配置灵活切换 |


---

_openclaw 技术分享_
