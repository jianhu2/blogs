---
title: "基于哪吒面板的笔记本远程唤醒与在线监控"
subtitle: "设计说明 · Wake-on-LAN + 哪吒触发任务 + OpenWrt 内网执行节点"
date: 2026-10-23T12:00:00+08:00
lastmod: "2026-10-23"
draft: false
tags: ["network", "linux", "tools", "nezha"]
hideFromHomePage: false
slug: "nezha-wol-remote-wake-design"
---

> **版本**：v1.0（2026-10-23）
> **适用对象**：运维/开发分享
> **关键词**：Wake-on-LAN、哪吒监控(Nezha v2.4.1)、触发任务、TCP 服务监控、OpenWrt 中转节点

---

## 1. 概述

### 1.1 目的
为内网一台 Windows 笔记本（物理下线/关机后）提供**远程、受控、可审计**的开机能力，并在面板上提供**可见的在线/离线状态**。整套能力复用现有哪吒监控面板，不引入独立服务端。

### 1.2 背景与约束
- 笔记本 `192.168.8.108`（= ZeroTier 内 `192.168.191.16`）位于家庭/办公内网，关机后仅网卡在 WoL 模式下监听"魔术包"。
- WoL 魔术包只能在**同一物理二层网段**广播/单播送达；公网上的哪吒面板服务器不在该网段，**无法直接唤醒**。
- 同网段有一台常在线的 OpenWrt 设备 **duckling**（哪吒 agent id=19，`br-wan 192.168.8.124/24`），可作为"发包执行节点"和"探测节点"。
- 笔记本自身跑了 xray/clash 的 TUN 代理，会在 WFP 底层劫持去 `192.168.8.0/24` 的流量，**不能用笔记本自己**去够同段设备；duckling 无此劫持，是干净节点。

### 1.3 术语
| 术语 | 含义 |
|------|------|
| WoL | Wake-on-LAN，网卡收到"魔术包"后唤醒主机 |
| 魔术包 | 6 字节 `0xFF` + 目标 MAC 重复 16 次 = 102 字节 |
| 触发任务 | 哪吒中按需手动执行的命令任务（`crons.task_type=1`） |
| 服务监控 | 哪吒中周期性探测目标可用性的监控项（`services`，type=3 为 TCP） |
| 执行/探测节点 | 真正在内网执行命令或发起探测的 agent，本系统为 duckling(id=19) |

---

## 2. 总体设计

### 2.1 系统结构图
```text
                         ┌─────────────────────────────────────────────────────┐
                         │   哪吒面板服务器  (公网 VPS，地址已脱敏)              │
   admin 浏览器          │                                                     │
    (已登录面板)         │   nginx :443 ──proxy──► nezha-service 容器 127.0.0.1:8008
        │  HTTPS         │                           │  (ghcr.io/nezhahq/nezha 2.4.1)
        └───────────────►│                           ├─ sqlite.db (users/crons/services/nz_waf…)
                         │                           └─ VictoriaMetrics tsdb (延迟/状态历史)
                         │   systemd timers (每分钟):                          │
                         │     • nezha-debounced-offline-monitor.py  登录API拉状态→飞书
                         │     • nezha-debounced-tcp-monitor.py      直探TCP→飞书
                         └───────────────────────────▲─────────────────────────┘
                                                      │ gRPC 长连（agent 出站发起）
                                       下发 Task(Exec / TCPPing)  ▲  回报 stdout/exit、探测结果
                                                      │
                         ┌────────────────────────────┴───────────────────────┐
                         │   duckling  OpenWrt  哪吒 id=19                       │
                         │   br-lan 192.168.31.1/24   br-wan 192.168.8.124/24   │
                         │   角色：WoL 发包节点 + TCP 探测节点                   │
                         │   能力：bash5.2(/dev/udp,/dev/tcp 可用)、nc、opkg     │
                         └────────────────────────────┬───────────────────────┘
                                                      │ 同一物理网段 192.168.8.0/24（经网关 192.168.8.1）
                         ┌────────────────────────────┴───────────────────────┐
                         │   笔记本 LAPTOP-SL0PIE1O  (Windows 11 家庭版)        │
                         │   eth2 Realtek GbE  MAC AA-BB-CC-DD-EE-FF (有线)     │
                         │   192.168.8.108  (= ZeroTier 192.168.191.16)         │
                         │   RDP:3389 (RDP Wrapper)   WakeOnMagicPacket=Enabled │
                         └──────────────────────────────────────────────────────┘
```

### 2.2 设计要点
1. **执行下沉到内网节点**：唤醒/探测都由 duckling 执行，面板只负责鉴权、下发、展示。
2. **复用面板鉴权**：触发任务只能由登录的 admin 触发（`POST /api/v1/cron/{id}/manual` 需鉴权），天然满足"admin 登录后才能操作"。
3. **幂等安全**：唤醒动作内置在线检测，在线则跳过、不发包，误触发无副作用。
4. **只让正确节点探测**：TCP 监控用 `cover + skip_servers` 白名单，**仅 duckling** 探测内网地址，避免全球节点误报离线。

### 2.3 数据流（唤醒）
```text
admin 点击 → nginx → nezha-service(鉴权) → gRPC 下发 Exec 任务 → duckling 执行脚本
  → [在线?] 是：输出“跳过”；否：构造魔术包→单播到 .108:9/UDP → 笔记本网卡唤醒
  → stdout/exit 回报 → 面板弹窗展示结果
```

---

## 3. 模块设计

| 模块 | 载体/位置 | 功能 |
|------|-----------|------|
| M1 唤醒触发任务 | 哪吒 `crons` 表 id=2「WoL-唤醒笔记本」 | 承载唤醒命令，admin 手动触发，目标=duckling |
| M2 WoL 执行脚本 | M1 的 `command` 字段（base64 封装的 bash） | 在 duckling 上执行"检测在线→否则发魔术包" |
| M3 TCP 在线监控 | 哪吒 `services` 表 id=6「笔记本-8.108 RDP在线」 | duckling 每 60s 探 `192.168.8.108:3389`，面板展示在线/离线+延迟 |
| M4 离线告警脚本 | `/usr/local/sbin/nezha-debounced-offline-monitor.py` | 每分钟登录面板拉 server 状态，防抖后飞书告警（既有） |
| M5 TCP 告警脚本 | `/usr/local/sbin/nezha-debounced-tcp-monitor.py` | 每分钟直探 TCP 端点，防抖后飞书告警（既有） |
| M6 反向代理 | 宿主 nginx `sites-available/<面板域名>` | TLS 终结，443 → 127.0.0.1:8008 |
| M7 凭据与鉴权 | 监控脚本凭据配置 / 面板 JWT+CSRF+WAF | 脚本登录凭据；面板会话鉴权与暴力登录防护 |

### 3.1 M1 唤醒触发任务（crons id=2）
| 字段 | 值 | 说明 |
|------|-----|------|
| `task_type` | 1 | 触发任务（0 为计划任务）。启动加载时触发任务不注册调度器，无需合法 cron 表达式 |
| `cover` | 0 | `CronCoverIgnoreAll`：`servers_raw` 为**白名单** |
| `servers_raw` | `[19]` | 仅在 duckling 执行 |
| `scheduler` | 空 | 触发任务不使用 |
| `command` | `echo <base64> \| base64 -d \| bash` | 用 base64 封装脚本，规避跨 shell 转义问题 |

### 3.2 M3 TCP 在线监控（services id=6）
| 字段 | 值 | 说明 |
|------|-----|------|
| `type` | 3 | TCP 探测（1 HTTP、2 ICMP、3 TCP） |
| `target` | `192.168.8.108:3389` | 探测笔记本的 RDP 端口作为"在线"判据 |
| `cover` | 1 | `ServiceCoverIgnoreAll`：`skip_servers` 为**白名单** |
| `skip_servers_raw` | `{"19":true}` | 仅 duckling 探测（避免海外节点误报） |
| `duration` | 60 | 探测周期（秒） |
| `enable_show_in_service` | 1 | 在"服务"页展示 |

---

## 4. 接口设计

### 4.1 面板 HTTP API（经 nginx `https://<面板域名>`）
| 方法/路径 | 用途 | 鉴权 | 备注 |
|-----------|------|------|------|
| `POST /api/v1/login` | 用户名/密码换 JWT | 无（登录本身） | 直连 127.0.0.1 时需带 `nz-realip` 头；失败累积触发 WAF |
| `POST /api/v1/cron/{id}/manual` | 手动触发任务（M1） | JWT + CSRF | 唤醒按钮/面板「执行」走此接口 |
| `GET /api/v1/server` | 拉取所有 server 状态 | JWT | M4 每分钟调用 |
| `GET /api/v1/service` | 拉取服务监控状态 | JWT/部分公开 | 展示在线/离线 |
| `GET /api/v1/ws/server` | 实时状态 WebSocket | 公开 | 面板首页数据源 |

**鉴权链**：`auth := api.Group("", authMw, csrfMiddleware())`。
- `authMw`：从 `Authorization: Bearer` / `?token=` / Cookie `nz-jwt` 取 JWT；校验 `jwt_sessions` 会话、`token_version`、IP 一致性。
- `csrfMiddleware`：非安全方法（POST/PATCH/DELETE）需携带 CSRF 头，值取自登录下发的 CSRF Cookie（双提交）。浏览器端由前端自动带；脚本直连需自行复刻。

### 4.2 Agent gRPC 接口（nezha-service ↔ duckling）
- agent 出站建立长连；面板通过 `server.SendTask(&proto.Task{Type, Data})` 下发任务。
- 任务类型（`model`）：`TaskTypeTCPPing=3`（服务探测）、`TaskTypeExec=34`（命令执行，M1 唤醒走此类）、`TaskTypeTerminalGRPC`（网页终端）。
- 前提：duckling 的 agent 必须**允许命令执行**（`disable_command_execute=false`）；网页终端可用即证明已开启。

### 4.3 数据库接口（SQLite：`/root/tools/nezha/dashboard-service/data/sqlite.db`）
| 表 | 关键列 | 用途 |
|----|--------|------|
| `crons` | id,name,task_type,command,cover,servers_raw,last_executed_at,last_result | 任务定义与执行结果 |
| `services` | id,name,type,target,cover,skip_servers_raw,duration,enable_show_in_service | 服务监控定义 |
| `users` | id,username,password(bcrypt),token_version,reject_password | 账号；密码为 bcrypt 单向哈希，不可逆 |
| `nz_waf` | ip(16B),block_identifier,block_reason,block_timestamp,count | 暴力登录等拦截记录 |
| `jwt_sessions` | key_id,user_id,ip,expires_at | 已签发会话 |
| `api_tokens` | — | 面板 API Token（脚本免密登录的推荐方案） |

> 直接改库后需 `docker restart nezha-service` 让其重新加载；改前务必备份 `sqlite.db`。

### 4.4 操作系统/网络接口
- `ip neigh replace|del`：维护静态 ARP（关机目标无 ARP，必须手动指定 MAC）。
- `bash /dev/udp/<ip>/<port>`：发送 UDP（无 `SO_BROADCAST`，故用单播而非广播）。
- `bash /dev/tcp/<ip>/<port>` + `timeout`：在线探测。

---

## 5. 算法设计

### 5.1 魔术包构造算法
```text
输入: MAC = AA:BB:CC:DD:EE:FF
步骤:
  hex   = 去冒号(MAC)              # "AABBCCDDEEFF"
  body  = hex 重复 16 次           # 16 × 6 字节
  packet= 0xFF×6  ++  body         # 6 + 96 = 102 字节
输出: 102 字节二进制，经 printf 写入 UDP 套接字
复杂度: O(1)（定长 102 字节）
```
实现要点：bash 内 `b="$b\\x${hex:$i:2}"` 把每两位十六进制转成 `\xNN` 转义，`printf` 据此输出真实字节。

### 5.2 在线检测算法
```text
对端口 p ∈ {3389, 22}:
    若 timeout 2 bash -c 'exec 3<>/dev/tcp/IP/p' 成功 → 判定在线, 跳出
在线 ⇒ 输出“已在线，跳过” 并 exit 0
离线 ⇒ 进入唤醒流程
```
选 3389（RDP，用户关心的服务）与 22（SSH，恒开）双保险；用 `timeout` 防止 SYN 无响应时长时间阻塞。

### 5.3 静态 ARP 单播发送算法
```text
原因: 目标关机无 ARP 回应，且 bash /dev/udp 不设 SO_BROADCAST（无法广播）
做法: ip neigh replace .108 lladdr MAC dev br-wan nud permanent  # 临时钉死映射
      printf <102字节> > /dev/udp/192.168.8.108/9                # 单播帧定向到该 MAC
      ip neigh del .108 dev br-wan                               # 发完清除，避免机器回来后 ARP 被钉住
端口 9: discard，WoL 与端口无关，网卡按帧内容匹配
```

### 5.4 服务监控覆盖判定算法（谁来探测）
```text
对每个上报 agent reporter:
  switch service.Cover:
    case ServiceCoverAll(0):      if skip_servers[reporter]        : 不探测
    case ServiceCoverIgnoreAll(1):if not skip_servers[reporter]    : 不探测
本系统 cover=1, skip={19:true} ⇒ 仅 duckling 探测
```

### 5.5 离线告警防抖算法（M4）
```text
周期(每分钟):
  servers = GET /api/v1/server
  对每台(排除 excluded_server_ids):
     stale = now - last_active
     若 stale ≥ offline_after_seconds 且 状态由“在线”翻转：记首次离线时间
     持续离线 ≥ 阈值 → 首次告警；之后每 reminder_seconds 复提醒
     恢复在线 → 发送恢复并清状态
  状态持久化到 state.json（跨周期防抖、防重复告警）
```

---

## 6. 流程图

### 6.1 唤醒触发整体时序
```text
admin浏览器     nginx:443     nezha-service       duckling(agent)        笔记本
   │ 点“执行”      │               │                     │                  │
   │ POST /cron/2/manual (nz-jwt + CSRF)                  │                  │
   │─────────────►│──────────────►│                      │                  │
   │              │               │ 鉴权(JWT+CSRF)       │                  │
   │              │               │ SendTask(Exec,cmd)   │                  │
   │              │               │───gRPC──────────────►│                  │
   │              │               │                      │ echo|base64 -d|bash
   │              │               │                      │ ①探 3389/22       │
   │              │               │                      │───TCP SYN───────►│
   │              │               │                      │◄──在线:RST/ACK───│
   │              │               │                      │ 在线→“跳过” exit0 │
   │              │               │◄─回报 stdout,exit────│                  │
   │◄─200 + 结果弹窗│◄─────────────│                      │                  │
   （离线分支：②构造魔术包→写静态ARP→UDP/9单播→删ARP→“已发送”）
```

### 6.2 WoL 执行脚本流程（M2）
```text
          ┌───────┐
          │ 开始  │
          └───┬───┘
              ▼
      探测 .108:3389 ──在线──┐
          │不通               │
          ▼                   │
      探测 .108:22 ──在线─────┤
          │不通               ▼
          ▼            输出“已在线(端口x)，跳过唤醒”
   写静态 ARP(.108→MAC)         │
          │                    ▼
          ▼                 exit 0
   构造魔术包 FF×6+MAC×16(102B)
          │
          ▼
   printf 字节 > /dev/udp/.108/9 （单播）
          │
          ▼
   删除静态 ARP
          │
          ▼
   输出“WoL 已发送” → exit 0
```

### 6.3 TCP 在线监控流程（M3）
```text
每 duration(60s):
   nezha 生成 TCPPing 任务 ──覆盖判定(§5.4)──► 仅下发给 duckling
                                                   │
                                   duckling: connect .108:3389 ?
                                       ├─成功→ 上报 在线 + 延迟
                                       └─失败→ 上报 离线
                                                   │
                                   面板“服务”页: 在线/离线 + 历史延迟曲线
```

### 6.4 逻辑框图（控制/数据）
```text
 [admin 鉴权域] ── 触发 ──► [任务调度 crons] ── gRPC ──► [内网执行 duckling]
        ▲                                                      │
        │                                           ┌──────────┴──────────┐
 [WAF/JWT/CSRF]                                      │ WoL 发包   TCP 探测  │
        ▲                                            └──────────┬──────────┘
        │                                                       ▼
 [凭据/会话 users/jwt_sessions]                         [目标笔记本 .108]
        ▲                                                       │
        │                                                       ▼
 [监控脚本 M4/M5] ──每分钟 login/探测──► [states] ──► [飞书告警]  [服务页状态]
```

---

## 7. 运行设计

### 7.1 部署与载体
| 组件 | 位置 | 运行方式 |
|------|------|----------|
| nezha-service | 容器 `nezha-service` | 常驻；改库后 `docker restart` 重载 |
| nginx | 宿主 | 常驻；证书经 acme.sh 续期 |
| M1/M3 定义 | sqlite.db | 面板启动时加载 |
| M4/M5 | `/usr/local/sbin/*.py` | systemd timer 每分钟触发（oneshot，跑完 inactive 属正常） |
| M2 执行 | duckling bash | 按需触发；root 身份（`ip neigh`/`/dev/udp` 需要） |

### 7.2 关键约束与前提
- 笔记本网卡 `WakeOnMagicPacket=Enabled`、有线连接、**正常关机**（死机唤不醒）。BIOS 侧 PCIe/网络唤醒开关未远程核实，唤不醒时先查 BIOS。
- duckling 需 root、bash（/dev/udp、/dev/tcp 可用）、base64、timeout。
- duckling 与笔记本必须同物理二层网段（`192.168.8.0/24`）。

### 7.3 验证记录（2026-10-23）
- 面板 `POST /api/v1/cron/2/manual` 返回 200；`crons.last_result=1`（成功）。
- 笔记本在线时触发，走"已在线，跳过"分支，未发包——符合预期。
- 真实唤醒需等笔记本处于关机态再触发。

---

## 8. 安全设计
- **访问控制**：唤醒/查看均需面板 admin 会话（JWT）；非安全请求受 CSRF 保护。
- **暴力防护**：登录失败累积写 `nz_waf`，源 IP 被临时拦截（表现为 403）。
- **改进建议**：M4 需要每分钟用账号密码登录面板拉取状态。建议改用面板 **API Token**（`api_tokens`）替代密码登录，缩小凭据暴露面，并避免每分钟新建 JWT 会话。
- **密钥材料**：JWT/agent secret 位于容器配置 `config.yaml`，不出库；本文不含任何口令。

---

## 9. 函数/命令清单

### 9.1 M4 `nezha-debounced-offline-monitor.py`
| 函数 | 功能 |
|------|------|
| `load_json(path, default)` | 读 JSON 配置/状态，缺失返回默认 |
| 原子写状态 | `os.fdopen` 临时文件写 + 替换，防半写 |
| `fetch_servers(base_url)` | `POST /login` 换 token → `GET /server` 返回状态 |
| `notification_configs()` | 读通知组配置（飞书） |
| `main()` | 读配置→拉状态→防抖判离线/恢复→告警→存状态 |
| 关键配置 | `dashboard_url / offline_after_seconds / reminder_seconds / excluded_server_ids` |

### 9.2 M5 `nezha-debounced-tcp-monitor.py`
| 函数 | 功能 |
|------|------|
| `load_json` / 原子写 | 同上 |
| `probe(host, port, timeout)` | 直接 TCP 连接探测端点 |
| `notification_configs()` | 飞书通知配置 |
| `main()` | 遍历 endpoints 探测→连续失败/恢复阈值防抖→告警 |
| 关键配置 | `endpoints[host,port] / timeout_seconds / failure_threshold / recovery_successes / probe_node` |

### 9.3 运维脚本（本次新增，仓库留档）
| 脚本 | 功能 |
|------|------|
| `scripts/ensure_rdp.ps1` | 笔记本侧：开机/定时保证 RDP(3389) 可用（与本系统互补） |
| 建任务 `build_wol_cron.py`（临时） | 生成 base64 唤醒命令并写入 `crons`（一次性） |
| 建监控 `add_wol_monitor.py`（临时） | 写入 `services` TCP 监控（一次性） |

> 临时脚本仅用于一次性落库，不常驻；核心定义已持久化在 sqlite。

---

## 10. 故障排查
| 现象 | 排查 |
|------|------|
| 点"执行"报错/`last_result=0` | 看面板弹窗 stdout；核 duckling 是否有 base64/timeout/bash、agent 是否允许命令执行 |
| 唤不醒 | 确认是"正常关机"而非死机；查 BIOS WoL、网卡 WoL；确认走的是有线 eth2；确认 MAC 正确 |
| 监控恒显示离线 | 确认仅 duckling 探测（`skip_servers={19:true}`）；确认 duckling 与 .108 同网段可达 |
| 每分钟登录 403 | admin 密码变更需同步监控脚本的凭据配置；清 `nz_waf` 中本机 IP 拦截 |

---

## 11. 局限
- 仅能唤醒"正常关机 + 已启用 WoL + 有线"的目标；死机需物理断电。
- 依赖 duckling 在线；duckling 掉线则无法唤醒/探测。
- 监控脚本"每分钟密码登录"为既有设计债，建议迁移 API Token。

---

## 12. 附录：关键参数
| 项 | 值 |
|----|-----|
| 唤醒目标 IP / MAC | `192.168.8.108` / `AA-BB-CC-DD-EE-FF`（eth2 有线） |
| 执行/探测节点 | duckling，哪吒 id=19，`br-wan 192.168.8.124` |
| 触发任务 | `crons` id=2「WoL-唤醒笔记本」 |
| TCP 监控 | `services` id=6「笔记本-8.108 RDP在线」→ `192.168.8.108:3389` |
| 面板 | `<面板域名>`（nginx）→ 容器 `127.0.0.1:8008`（nezha 2.4.1） |
| 相关文档 | `docs/win-rdp-wrapper-192.168.191.16.md`（RDP 排障 + WoL 手动步骤） |
| 参考项目 | [WOL-plus](https://github.com/leeyeel/WOL-plus)（见 §13） |

---

## 13. 参考项目与借鉴：WOL-plus

参考 [leeyeel/WOL-plus](https://github.com/leeyeel/WOL-plus)（MIT）。该项目是一套"唤醒 + 远程关机"工具，基于**本地二层原始帧**，含三部分：
- **Client**（Linux/Windows，libpcap/Npcap 抓包）：捕获 EtherType `0x0842` 且匹配 6 字节判别码的帧，触发**可取消的关机倒计时**，带 Web UI（端口 2025，默认口令 `admin/admin123`）。
- **OpenWrt LuCI 应用**：用 `etherwake` 发送唤醒/关机帧。
- **Agent skill**：`skill/wolp/scripts/wolp_power.py`，Python CLI，需 `CAP_NET_RAW`/root。

### 13.1 方案对比
| 维度 | 本系统 | WOL-plus |
|------|--------|----------|
| 发包节点 | OpenWrt(duckling)，经哪吒触发任务 | OpenWrt LuCI / Linux Client / Python CLI |
| 发包方式 | bash `/dev/udp` 单播 + 临时静态 ARP | `etherwake` 原始二层帧（默认广播） |
| 唤醒前在线检测 | **有**（探 3389/22，在线则跳过） | 无（项目未提供，其文档把"先检测再唤醒"列为建议） |
| 远程关机 | 无（走 SSH/RDP 关机） | **有**（魔术包 + 6 字节判别码，Client 抓包执行） |
| 控制入口/鉴权 | 复用哪吒 admin 会话（JWT+CSRF+WAF） | 独立 Web UI + HTTP 登录（默认弱口令，需改） |
| 部署形态 | 零新增服务，复用面板 | 需在目标装 Client，另起 Web 服务 |

### 13.2 可借鉴点
1. **用 `etherwake` 替代"静态 ARP + /dev/udp"**：duckling 有 `opkg`，可 `opkg install etherwake`，则发包简化为
   `etherwake -i br-wan AA:BB:CC:DD:EE:FF`——它直接构造二层广播帧，**无需手动钉 ARP、无需 /dev/udp**，更健壮。
   本系统选 `/dev/udp` 仅因"免安装、已验证可用"；若后续想降复杂度，这是首选替代实现（把 M2 的 `command` 换成 etherwake 即可，其余不变）。
2. **远程关机能力**：如需"远程关机"闭环，可参考其 Client（抓 `0x0842` 判别码帧）。本系统目前关机依赖 SSH/RDP，已够用；若要免登录关机再评估。注意其已知问题——关机帧本身也是合法魔术包，可能先唤醒再关机，务必限本网段使用。
3. **安全告诫印证**：WOL-plus 默认 `admin/admin123` 与 6 字节弱判别码的问题，正对应本系统 §8 的整改项（密码登录 → 迁移 API Token、避免弱口令）。

### 13.3 不直接采用其整体方案的原因
WOL-plus 需要在目标笔记本常驻 Client、另开 Web 服务与独立鉴权；本系统的目标是**零新增服务、复用既有哪吒面板与内网节点**，并以"在线检测 + 幂等触发"满足低频远程开机诉求。故仅借鉴其 `etherwake` 发包与关机思路，不引入其独立服务端。
