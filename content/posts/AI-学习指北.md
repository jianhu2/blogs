---
title: "AI 学习指北"
subtitle: ""
date: 2026-03-17T00:19:04+08:00
lastmod: "2026-03-18"
draft: false
tags: ["AI"]
hideFromHomePage: false
---
### **Last news**
+ [大模型 2024-25 年发展了哪些方面](https://www.bestblogs.dev/en/article/ece92a)
+ [2025 年上半年AI使用情况和趋势](https://artificialanalysis.ai/downloads/ai-adoption-survey/2025/Artificial-Analysis-AI-Adoption-Survey-H1-2025.pdf)
+ [2025 China AI 现状](https://artificialanalysis.ai/downloads/china-report/2025/Artificial-Analysis-State-of-AI-China-Q2-2025-Highlights.pdf)
+ [2026 Agent 智能体](https://github.com/openclaw/openclaw)

## **名词解释**
### LLM（Large Language Model，大语言模型）
#### 定义
LLM 是基于海量文本数据训练的深度学习模型，能够理解、生成和推理人类语言，通过预测文本序列的概率分布实现智能交互。

![llm.png](/images/llm.png)

### RAG（Retrieval-Augmented Generation，检索增强生成）
#### 定义
RAG 是一种将实时信息检索与大语言模型结合的架构，通过从外部知识库动态提取相关数据，增强LLM生成答案的准确性和时效性。

#### RAG 的典型工作流
1. 用户输入问题。
2. 将问题向量化，然后检索最相似的文档切片。
3. 将检索到的上下文与问题拼接后输入 LLM。
4. LLM 输出带引用信息的回答。
5. 前端渲染回答、可选地在可视化界面中展示引用详情。

![rag.png](/images/rag.png)

+ RAG和LLM区别：
    - RAG 不是新模型，而是LLM的增强框架。
    - LLM是RAG的生成引擎，检索系统是RAG的知识补给站。

| **<font style="color:#1f2329;">术语</font>** | **<font style="color:#1f2329;">本质</font>** | **<font style="color:#1f2329;">解决痛点</font>** | **<font style="color:#1f2329;">是否可独立存在</font>** |
| --- | --- | --- | --- |
| <font style="color:rgb(0, 0, 0);">LLM</font> | <font style="color:rgb(0, 0, 0);">通用语言智能体</font> | <font style="color:rgb(0, 0, 0);">自动化文本生成与理解</font> | <font style="color:rgb(0, 0, 0);">是</font> |
| <font style="color:rgb(0, 0, 0);">RAG</font> | <font style="color:rgb(0, 0, 0);">LLM的“扩展知识站”</font> | <font style="color:rgb(0, 0, 0);">突破静态知识边界+减少幻觉</font> | <font style="color:rgb(0, 0, 0);"> 否（依赖LLM）</font> |


### MCP（Model Context Protocol）
Model Context Protocol (MCP) 是由 Anthropic 开发的开放标准协议，为 AI 与外部工具和数据源提供标准化交互接口。AI 通过此协议访问软件工具和数据资源。


![mcp.png](/images/mcp.png)

RAG 和MCP可以相互协作

RAG 解决“知道什么”，MCP 解决“能做什么”

详细了解 MCP 协议，请参考 [Model Context Protocol](https://docs.anthropic.com/en/docs/agents-and-tools/mcp)。

### 蒸馏技术**（Knowledge Distillation）**
#### 基本定义
**蒸馏技术（Knowledge Distillation）** 的主要思想是：

**用一个训练好的****大模型****（Teacher）指导一个小模型（Student）学习，从而让小模型获得大模型的能力。**

#### 解决了什么问题？
以[DeepSeek-R1](https://huggingface.co/deepseek-ai/DeepSeek-R1)为例，它提供了卓越的推理能力，但是其超大的模型尺寸(671B)会消耗较大的模型推理资源。为此我们可以通过模型蒸馏的方式将 DeepSeek-R1 的推理能力迁移到开源小尺寸模型(例如[Llama-3.2-3B](https://huggingface.co/meta-llama/Llama-3.2-3B))上，从而在保证效果的同时降低推理消耗成本。

| **<font style="color:rgb(0, 0, 0);">问题</font>** | **<font style="color:rgb(0, 0, 0);">蒸馏技术的作用</font>** |
| --- | --- |
| **<font style="color:rgb(0, 0, 0);">大模型太重，无法部署在移动端或边缘设备</font>** | <font style="color:rgb(0, 0, 0);">通过蒸馏将模型压缩成轻量化模型（如从 </font>[<font style="color:rgb(0, 0, 0);">DeepSeek-R1</font>](https://huggingface.co/deepseek-ai/DeepSeek-R1)<br/><font style="color:rgb(0, 0, 0);">→ </font>[<font style="color:rgb(0, 0, 0);">Llama-3.2-3B</font>](https://huggingface.co/meta-llama/Llama-3.2-3B)<br/><font style="color:rgb(0, 0, 0);">）</font> |
| **<font style="color:rgb(0, 0, 0);">推理速度太慢，延迟高</font>** | <font style="color:rgb(0, 0, 0);">Student 模型更小更快，能在低延迟场景下运行</font> |
| **<font style="color:rgb(0, 0, 0);">模型训练代价高（算力昂贵）</font>** | <font style="color:rgb(0, 0, 0);">用大模型离线生成指导信号，Student 可快速训练</font> |
| **<font style="color:rgb(0, 0, 0);">数据不足，难以训练小模型</font>** | <font style="color:rgb(0, 0, 0);">Teacher 提供“软标签”补充知识，缓解数据稀缺问题</font> |
| **<font style="color:rgb(0, 0, 0);">专业知识稀缺（如哪种虫害属于哪种病）</font>** | <font style="color:rgb(0, 0, 0);"> 利用大模型知识迁移到小模型</font> |


### 部署大模型服务器配置要求：
[以Deepseek为例最低服务器配置](https://apxml.com/zh/posts/gpu-requirements-deepseek-r1)

<!-- 这是一张图片，ocr 内容为： -->
![](https://cdn.nlark.com/yuque/0/2026/png/26909551/1773804199250-8070acab-5f6c-448c-a612-14209764b71c.png)

### 参考资料：
+ [RAG 2.0: A Deep Dive | BestBlogs.dev](https://www.bestblogs.dev/en/article/aaa15c)
+ [RAG打造知识库 QA 系统](https://github.com/rag-web-ui/rag-web-ui/tree/main/docs/tutorial)
+ [AI 大周边](https://yigegongjiang.notion.site/AI-1dbf4dacfccc80208a31e1d71536ad25)

## 模型对比
👍👍👍 [https://artificialanalysis.ai/](https://artificialanalysis.ai/)

查看模型被使用的 ranking：

[https://openrouter.ai/models](https://openrouter.ai/models)

[https://lmarena.ai/?leaderboard](https://lmarena.ai/?leaderboard)

### AI 资讯聚合页：不生产模型，仅提供新闻（方便快速查看有没有新的产品线出来）
AI 咨询平台：[https://www.toolify.ai/zh](https://www.toolify.ai/zh)

AI 聚合资讯平台：[https://ai-bot.cn/daily-ai-news/](https://ai-bot.cn/daily-ai-news/)

AI Product 聚合 md：[https://github.com/Eternaldeath/AIProductHome](https://github.com/Eternaldeath/AIProductHome)

+ 泛化的了解 AI 相关的 tools

ToolAI：[https://toolai.io/zh/ranking-top](https://toolai.io/zh/ranking-top)

+ AI 相关的排行榜

[2AI.cn](http://2AI.cn)：[https://www.2ai.cn/](https://www.2ai.cn/)

[Fast.ai](http://Fast.ai)：[https://www.fast.ai/](https://www.fast.ai/)

## AI 云产品
Google AI Studio(使用最新 Google 模型、支持 online search) [https://ai.dev](https://ai.dev)

👍 👍 👍 sumbuddy(chrome 插件，快速总结当前网页) [https://doc.sumbuddy.app/](https://doc.sumbuddy.app/)

👍 👍 👍 秘塔（DeepSeek 可高频使用） [https://metaso.cn/](https://metaso.cn/)

非论文等严肃资料查询，暂无更多优势。推荐使用【火山引擎】

👍 👍 👍 dify：[https://github.com/langgenius/dify](https://github.com/langgenius/dify)

开源的 RAG + Agent 生产力工具，支持 docker 部署

[302.ai](http://302.ai)：[https://302.ai/](https://302.ai/)[https://github.com/302ai/.github/blob/main/profile/README_zh.md](https://github.com/302ai/.github/blob/main/profile/README_zh.md)

在线互联网信息检索：[https://app.tavily.com](https://app.tavily.com)

影刀：[https://www.yingdao.com/](https://www.yingdao.com/)

fish speech：[https://github.com/fishaudio/fish-speech](https://github.com/fishaudio/fish-speech) 做文本、语音合成，开源

Lobe Chat：[https://github.com/lobehub/lobe-chat](https://github.com/lobehub/lobe-chat)

+ 同 dify

Google Labs 实验室：[https://labs.google/](https://labs.google/)

NotebookLM：[https://notebooklm.google.com/](https://notebooklm.google.com/) 文本处理，知识库，个人笔记

NewsNow：[https://github.com/ourongxing/newsnow](https://github.com/ourongxing/newsnow) 热点资讯

### Books
+ [LLM大模型基础](https://github.com/ZJU-LLMs/Foundations-of-LLMs)
+ [参考来源](https://yigegongjiang.notion.site/AI-2e72fbdad5bc4ee4b8f2c79cfaf927d2)

