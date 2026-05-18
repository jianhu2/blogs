# CLAUDE.md — 项目协作与发布规则

本文档面向所有维护者和 AI 助手。**改动前先读完"红灯清单"一节。**

## 1. 项目概况

- Hugo 静态博客，主题 `themes/NewBee`（已 vendor 进本仓库，不是 submodule）
- 内容源在 `content/posts/`，构建输出到 `public/`
- 域名：`jianhu.cc`（CNAME 在 `static/CNAME` 与 `public/CNAME`）
- 站点配置：`hugo.toml`（启用 CJK、taxonomies = categories / tags / series）

## 2. 本地开发与构建

| 操作 | 命令 |
|---|---|
| 本地预览（带 draft、热重载） | `hugo server -D` |
| 一次性构建到 `public/` | `hugo` |
| 创建新文章模板 | `hugo new posts/标题.md`（模板在 `archetypes/default.md`） |
| Makefile 构建 | `make build`（= `hugo`） |
| Makefile 同步到 minio | `make release`（`rclone sync public minio:blogs-rescoure`） |
| Makefile 打 Docker 镜像 | `make image`（Dockerfile 基于 `nginx:stable-alpine`，把 `public/` 拷进 nginx html 目录） |

`Dockerfile` 的镜像供华为云容器服务消费；主流量入口仍是 GitHub Pages，Docker 镜像是备用/自建部署。

## 3. 仓库拓扑（关键，不要搞错）

项目用**两个独立 git 仓库**，它们在磁盘上看似嵌套但 git 层面完全独立：

| 角色 | 路径 | Remote | 默认分支 |
|---|---|---|---|
| 源码仓库 | `D:\go\src\me\blogs\` | `ssh://git@sonoc.github.com/jianhu2/blogs.git` | `main` |
| 站点产物仓库 | `D:\go\src\me\blogs\public\` | `git@sonoc.github.com:jianhu2/jianhu2.github.io.git` | `master` |

- `public/` 目录有**自己的 `.git`**，远端是 GitHub Pages 仓库
- 主仓库的 `.gitignore` 包含 `public/`，**主仓库永远不应跟踪 public/ 下的任何文件**
- 两个仓库各自 commit / push，互不干涉

## 4. SSH 配置（必看）

两个 remote 都通过 ssh host 别名 `sonoc.github.com`（见 `~/.ssh/config`），它使用 `~/.ssh/id_ed25519` 作为 jianhu2 GitHub 身份。

**不要用裸 `git@github.com:...` URL** —— 默认 SSH key 解析到另一个账户（`kelleygo`），push 会被拒：
```
ERROR: Permission to jianhu2/...denied to kelleygo.
```

## 5. Commit 作者邮箱约定

| 仓库 | author email |
|---|---|
| `blogs`（源码） | 本地默认 `jameslabam3@gmail.com` |
| `jianhu2.github.io`（产物） | **`jianhu216@gmail.com`**（保持远端历史一致） |

`public/` 子仓库已用 `git config user.email jianhu216@gmail.com` 局部配置，不要改成全局。

## 6. 标准发布流程

```powershell
# === 1. 写/改内容、改主题，然后构建 ===
hugo                              # 生成 public/

# === 2. 主仓库提交源码改动 ===
# 主仓库不会有 public/ 改动（被 .gitignore）
git add content/ themes/ static/ <其他>
git commit -m "..."
git push origin main

# === 3. 站点产物独立提交 ===
cd public
git add -A
git commit -m "..."
git push origin master
cd ..
```

## 7. 文章 Frontmatter 约定

`archetypes/default.md` 是最小模板，但**实际文章里常用以下扩展字段**：

```yaml
---
title: "文章标题"
subtitle: ""
date: 2026-05-13T12:45:00+08:00
lastmod: "2026-05-17"
draft: false
tags: ["network", "lxc", "gost"]   # 小写、kebab-case，见 §8
hideFromHomePage: false             # true 则首页不展示
mermaid: true                       # 用 mermaid 图需要显式开启
image: "/images/封面.svg"           # 文章封面（首页/列表用）
heroImageFit: "cover"               # cover / contain
slug: "english-slug"                # URL 短链；不写默认用文件名
aliases:                            # 旧 URL 兼容
  - "/posts/旧路径/"
deprecated: true                    # 标记为过时，渲染会有提示
---
```

约定：
- **标签数组**：小写英文，kebab-case；同一文章可以有多个，宽-细粒度并存（例如 `["network", "lxc", "gost"]`）
- **`slug`**：含中文路径的文章建议加，便于 GitHub Pages / SEO
- **`aliases`**：迁移文件名后必须加，避免外链 404

## 8. Tag 配色系统

`themes/NewBee/layouts/partials/widgets/tag-style.html` 是真相源。每个 tag 名映射到一组配色（`from`/`to` 渐变 + FontAwesome 图标）：

```
ai / linux / network / website / tools / dev-env / oracle-cloud / lxc / gost
```

- **新增 tag** 时如果想要专属配色，必须在该文件 `$tagStyles` 字典里加一条；不加则回落到 fallback 灰色 `#64748b/#94a3b8` + `fa-file-text-o`
- 文章 frontmatter 里的 tag 名要跟字典的 key **完全一致**（小写）
- 改了该文件后需 `hugo` 重建 public/，否则线上看不到

## 9. Commit Message 风格

观察历史，本项目使用以下中文短前缀（不是严格 Conventional Commits）：

| 前缀 | 用途 |
|---|---|
| `feat:` | 新功能 / 新文章 |
| `fix:` | bug 修复 / 渲染问题 |
| `add:` | 新增内容（与 feat 边界模糊，历史上更常用） |
| `chore:` | 杂项、依赖、配置 |
| `docs:` | 文档（含 README、CLAUDE.md） |
| `edit:` | 微调（如改日期、改邮箱） |

主体用中文描述，可换行写细节。**两个仓库各自的 commit message 互不引用**——主仓库的 commit 不要写 "对应 jianhu2.github.io 的 xxx"，因为 hash 会变。

## 10. AI 助手红灯清单

操作前如果发现以下任一情况，**立刻停下来问用户**，不要自作主张：

1. **主仓库 `git status` 里出现 `public/...` 任何文件** → 异常。`public/` 应被 `.gitignore` 完全屏蔽。可能 `.gitignore` 被人改了，或 `public/.git` 不存在了。
2. **主仓库 commit 含 `public/` 路径** → 错误，应当回滚而不是 push。
3. **`public/` 内 `git remote -v` 不是 `jianhu2.github.io.git`** → 配置丢失，需要恢复。
4. **要 `git push --force` / `--force-with-lease`** → 必须先 `git bundle create ../<repo>-backup-<date>.bundle --all` 备份。
5. **要 `git filter-repo` 重写历史** → 同上，先备份；filter-repo 会自动移除 origin remote，记得重新加。
6. **看到 SSH 错误 `denied to kelleygo`** → remote URL 用了裸 `git@github.com:...`，应改为 `git@sonoc.github.com:...` 或 `ssh://git@sonoc.github.com/...`。

## 11. 常见恢复操作

### 主仓库 push 后想撤回最近一次 commit（远端已 push 给只有你一个的 main）

```powershell
git bundle create ../blogs-backup.bundle --all     # 备份
git revert <commit>                                # 推荐（安全可逆）
git push origin main
# 不要 git reset --hard + force push，除非确实必要
```

### `public/.git` 丢失（之前发生过一次）

```powershell
cd public
git init -b master
git config user.email jianhu216@gmail.com
git config user.name jianhu2
git remote add origin git@sonoc.github.com:jianhu2/jianhu2.github.io.git
git fetch origin master
git reset --soft FETCH_HEAD
git add -A
git commit -m "chore: 重新同步本地站点产物"
git push origin master
```

## 12. 历史性事件

- **2026-05-18**：把 `public/` 从主仓库拆出为独立子仓库，远端独立为 `jianhu2.github.io`；用 `git filter-repo --path public/ --invert-paths` 重写主仓库历史（55→54 commit，`.git` 体积 126.5→62.2 MB），force-with-lease 推送 main。同时把 `.claude/` 加入 `.gitignore`。
