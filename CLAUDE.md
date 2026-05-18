# CLAUDE.md — 项目协作与发布规则

本文档面向所有维护者和 AI 助手。**改动前先读完"红灯清单"一节。**

## 1. 项目概况

- Hugo 静态博客，主题 `themes/NewBee`
- 内容源在 `content/posts/`，构建输出到 `public/`
- 域名：`jianhu.cc`（CNAME 在 `static/CNAME` 与 `public/CNAME`）

## 2. 仓库拓扑（关键，不要搞错）

项目用**两个独立 git 仓库**，它们在磁盘上看似嵌套但 git 层面完全独立：

| 角色 | 路径 | Remote | 默认分支 |
|---|---|---|---|
| 源码仓库 | `D:\go\src\me\blogs\` | `ssh://git@sonoc.github.com/jianhu2/blogs.git` | `main` |
| 站点产物仓库 | `D:\go\src\me\blogs\public\` | `git@sonoc.github.com:jianhu2/jianhu2.github.io.git` | `master` |

- `public/` 目录有**自己的 `.git`**，远端是 GitHub Pages 仓库
- 主仓库的 `.gitignore` 包含 `public/`，**主仓库永远不应跟踪 public/ 下的任何文件**
- 两个仓库各自 commit / push，互不干涉

## 3. SSH 配置（必看）

两个 remote 都通过 ssh host 别名 `sonoc.github.com`（见 `~/.ssh/config`），它使用 `~/.ssh/id_ed25519` 作为 jianhu2 GitHub 身份。

**不要用裸 `git@github.com:...` URL** —— 默认 SSH key 解析到另一个账户（`kelleygo`），push 会被拒：
```
ERROR: Permission to jianhu2/...denied to kelleygo.
```

## 4. Commit 作者邮箱约定

| 仓库 | author email |
|---|---|
| `blogs`（源码） | 本地默认 `jameslabam3@gmail.com` |
| `jianhu2.github.io`（产物） | **`jianhu216@gmail.com`**（保持远端历史一致） |

`public/` 子仓库已用 `git config user.email jianhu216@gmail.com` 局部配置，不要改成全局。

## 5. 标准发布流程

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

## 6. AI 助手红灯清单

操作前如果发现以下任一情况，**立刻停下来问用户**，不要自作主张：

1. **主仓库 `git status` 里出现 `public/...` 任何文件** → 异常。`public/` 应被 `.gitignore` 完全屏蔽。可能 `.gitignore` 被人改了，或 `public/.git` 不存在了。
2. **主仓库 commit 含 `public/` 路径** → 错误，应当回滚而不是 push。
3. **`public/` 内 `git remote -v` 不是 `jianhu2.github.io.git`** → 配置丢失，需要恢复。
4. **要 `git push --force` / `--force-with-lease`** → 必须先 `git bundle create ../<repo>-backup-<date>.bundle --all` 备份。
5. **要 `git filter-repo` 重写历史** → 同上，先备份；filter-repo 会自动移除 origin remote，记得重新加。
6. **看到 SSH 错误 `denied to kelleygo`** → remote URL 用了裸 `git@github.com:...`，应改为 `git@sonoc.github.com:...` 或 `ssh://git@sonoc.github.com/...`。

## 7. 常见恢复操作

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

## 8. 历史性事件

- **2026-05-18**：把 `public/` 从主仓库拆出为独立子仓库，远端独立为 `jianhu2.github.io`；用 `git filter-repo --path public/ --invert-paths` 重写主仓库历史，剥离所有 public/ 数据；force-with-lease 推送 main。备份 bundle 保存在 `../blogs-backup-pre-filter-repo.bundle`。
