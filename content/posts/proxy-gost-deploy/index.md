---
title: "gost 一键中转：把带认证的 SOCKS5 转成本地无认证 HTTP+SOCKS5"
subtitle: "auto:// 单端口双协议 · systemd 守护 · 一条命令远程部署"
date: 2026-05-20T15:00:00+08:00
lastmod: "2026-05-20"
draft: false
tags: ["network", "gost", "linux", "tools"]
hideFromHomePage: false
slug: "proxy-gost-deploy"
---

> 把带账密的上游 SOCKS5 在内网"脱密"，对外暴露一个**同时支持 HTTP 和 SOCKS5** 的无认证端口。给 SmartProxy / SwitchyOmega 这类**不支持 SOCKS5 认证**的浏览器扩展用最舒服，内网多设备共用同一出口也一并解决。

## 为什么需要这层中转

供应商给的 SOCKS5 通常长这样：`socks5://USER:PASS@HOST:PORT`。直接丢进浏览器扩展会发现：

- **Chromium `chrome.proxy` API 不支持 SOCKS5 用户名密码** —— 这是底层限制，所有基于该 API 的扩展都吃不下账密；
- 想顺手暴露成 HTTP 代理（CONNECT 隧道）给别的工具用；
- 内网多台机器共用一个出口，不愿每台都填账密。

解法是在内网（或一台可控主机）跑一个 **gost** 中转：上游接带账密的 SOCKS5，对内监听**单一无认证端口**，HTTP 和 SOCKS5 都能识别。

```
[浏览器/curl] ──HTTP 或 SOCKS5（无认证）──▶ [中转主机:10083] ──SOCKS5（带认证）──▶ [上游出口] ──▶ 互联网
```

核心魔法是 gost 的 `auto://` 监听器：嗅探连接的首字节自动识别协议（HTTP / SOCKS4 / SOCKS5），**一个端口同时支持三种**。

## 一键部署脚本（推荐）

整套流程封装成了一个幂等的 SSH 部署脚本：探测远端架构、按需下载 gost、写 systemd unit、启用并自检三种协议。重复执行只动有变化的部分。

**下载：** [`deploy-gost-proxy.sh`](deploy-gost-proxy.sh)（与本文同目录，Hugo page bundle 直接挂载）。

凭据走环境变量，避免落进 shell 历史：

```bash
UPSTREAM_URL="socks5://USER:PASS@1.2.3.4:1083" \
  bash deploy-gost-proxy.sh --relay root@192.168.50.23
```

完整选项：

```bash
bash deploy-gost-proxy.sh \
  --relay         root@192.168.50.23 \
  --port          10083 \
  --install-dir   /root/tools/proxy/gost \
  --gost-version  2.12.0 \
  --service-name  gost-proxy \
  --upstream-url  "socks5://USER:PASS@1.2.3.4:1083"
```

脚本依次执行 5 步：

| 步骤 | 做的事 | 幂等性 |
|---|---|---|
| `[1/5] probe`   | SSH 探测远端架构（`x86_64` / `aarch64` / `armv7l` / `armv6l`）和 `systemctl` / `curl` / `tar` | 只读 |
| `[2/5] install` | 远端已是目标版本就跳过；否则按架构拉 GitHub release tarball                            | 版本一致即 no-op |
| `[3/5] unit`    | 本地拼好 systemd unit，通过 stdin 投递（凭据不出现在 SSH 命令行）；sha256 对比，**无变化不重启** | 内容一致即 no-op |
| `[4/5] enable`  | `daemon-reload` + `enable --now`，仅 unit 变了才 `restart`                            | 状态收敛 |
| `[5/5] verify`  | 检查端口 `LISTEN`；分别用 HTTP 和 SOCKS5 走中转打 `ip-api.com/json`，**直接看到出口 IP** | 失败立刻 `exit 1` |

### 安全说明

- `UPSTREAM_URL` 经 stdin 投递，**不进**远端 shell history、不进 `ps` 输出；
- 远端 `/etc/systemd/system/gost-proxy.service` 含明文上游 URL，脚本会把它 `chmod 600`；
- 进一步把凭据外置到 `EnvironmentFile`，见后文「加固建议」。

### 脚本全文

下面是 `deploy-gost-proxy.sh` 的完整内容，与上面的下载链接一致：

```bash
#!/usr/bin/env bash
# Deploy a gost SOCKS5/HTTP relay onto a remote Linux host via SSH.
#
# Result: an `auto://` listener that accepts HTTP + SOCKS5 on a single LAN port,
# forwarding to an authenticated upstream SOCKS5 proxy. Managed by systemd,
# auto-starts at boot.
#
# Usage:
#   UPSTREAM_URL="socks5://user:pass@1.2.3.4:1083" \
#     bash deploy-gost-proxy.sh --relay root@192.168.50.23
#
#   bash deploy-gost-proxy.sh \
#     --relay root@192.168.50.23 \
#     --port 10083 \
#     --upstream-url "socks5://user:pass@1.2.3.4:1083"
#
# Re-running is safe (idempotent): re-downloads gost only if missing or version
# changed, and re-writes the systemd unit only when content differs.
#
# Companion runbook: https://jianhu.cc/posts/proxy-gost-deploy/

set -euo pipefail

# -------- defaults --------
RELAY=""
LISTEN_PORT="10083"
INSTALL_DIR="/root/tools/proxy/gost"
GOST_VERSION="2.12.0"
SERVICE_NAME="gost-proxy"
UPSTREAM_URL="${UPSTREAM_URL:-}"
LOG_FILE="/var/log/gost-proxy.log"
SSH_OPTS=(-o ConnectTimeout=8 -o ServerAliveInterval=60 -o ServerAliveCountMax=3)

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  cat <<EOF

Options:
  --relay <user@host>     SSH target running the relay (required)
  --port <port>           Listen port on relay, default ${LISTEN_PORT}
  --install-dir <dir>     Remote install dir, default ${INSTALL_DIR}
  --gost-version <ver>    gost v2.x release, default ${GOST_VERSION}
  --upstream-url <url>    Upstream proxy URL (or set UPSTREAM_URL env var)
  --service-name <name>   systemd unit name, default ${SERVICE_NAME}
  -h, --help              Show this help

Security:
  Pass UPSTREAM_URL via environment to keep credentials out of shell history:
    UPSTREAM_URL="socks5://u:p@h:port" bash deploy-gost-proxy.sh --relay root@host

  The remote systemd unit will contain the upstream URL in plaintext at
  /etc/systemd/system/${SERVICE_NAME}.service. The script chmods it to 600.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --relay)          RELAY="$2"; shift 2 ;;
    --port)           LISTEN_PORT="$2"; shift 2 ;;
    --install-dir)    INSTALL_DIR="$2"; shift 2 ;;
    --gost-version)   GOST_VERSION="$2"; shift 2 ;;
    --upstream-url)   UPSTREAM_URL="$2"; shift 2 ;;
    --service-name)   SERVICE_NAME="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# -------- validate inputs --------
[[ -n "$RELAY" ]]        || { echo "ERROR: --relay is required" >&2; exit 2; }
[[ -n "$UPSTREAM_URL" ]] || { echo "ERROR: --upstream-url or UPSTREAM_URL env required" >&2; exit 2; }
[[ "$UPSTREAM_URL" =~ ^(socks5|socks4|http|https):// ]] \
  || { echo "ERROR: UPSTREAM_URL must start with socks5:// / socks4:// / http(s)://" >&2; exit 2; }
[[ "$LISTEN_PORT" =~ ^[0-9]+$ ]] && (( LISTEN_PORT > 0 && LISTEN_PORT < 65536 )) \
  || { echo "ERROR: invalid port: $LISTEN_PORT" >&2; exit 2; }

# Mask credentials for log output
mask_url() {
  # Replace user:pass@ with ***@ for display
  sed -E 's#://[^@/]+@#://***@#' <<<"$1"
}

cat <<EOF
=== gost relay deployment ===
  relay        : $RELAY
  listen       : 0.0.0.0:$LISTEN_PORT  (HTTP + SOCKS5 via auto://)
  install dir  : $INSTALL_DIR
  gost version : v$GOST_VERSION
  service      : $SERVICE_NAME
  upstream     : $(mask_url "$UPSTREAM_URL")
  log file     : $LOG_FILE
EOF

ssh_run() {
  ssh "${SSH_OPTS[@]}" "$RELAY" "$@"
}

ssh_run_in() {
  # Pipe stdin into a remote bash -s session
  ssh "${SSH_OPTS[@]}" "$RELAY" "bash -s"
}

# -------- step 1: probe remote --------
echo
echo "[1/5] probing remote host..."
REMOTE_INFO=$(ssh_run 'set -e
  uname -m
  test -x /usr/bin/systemctl && echo systemctl-ok || echo systemctl-missing
  test -x /usr/bin/curl && echo curl-ok || echo curl-missing
  test -x /usr/bin/tar && echo tar-ok || echo tar-missing
')

ARCH=$(awk 'NR==1' <<<"$REMOTE_INFO")
echo "  remote arch : $ARCH"
echo "$REMOTE_INFO" | tail -n +2 | sed 's/^/  /'

grep -q 'systemctl-missing' <<<"$REMOTE_INFO" && { echo "ERROR: systemd required on relay" >&2; exit 1; }
grep -q 'curl-missing'      <<<"$REMOTE_INFO" && { echo "ERROR: curl required on relay" >&2; exit 1; }
grep -q 'tar-missing'       <<<"$REMOTE_INFO" && { echo "ERROR: tar required on relay" >&2; exit 1; }

case "$ARCH" in
  x86_64)  GOST_ARCH="amd64" ;;
  aarch64) GOST_ARCH="arm64" ;;
  armv7l)  GOST_ARCH="armv7" ;;
  armv6l)  GOST_ARCH="armv6" ;;
  *) echo "ERROR: unsupported arch: $ARCH" >&2; exit 1 ;;
esac
GOST_TARBALL="gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz"
GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/${GOST_TARBALL}"
echo "  download    : $GOST_URL"

# -------- step 2: install gost --------
echo
echo "[2/5] installing gost..."
ssh_run_in <<REMOTE
set -euo pipefail
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

want_version="$GOST_VERSION"
have_version=""
if [[ -x ./gost ]]; then
  have_version="\$(./gost -V 2>&1 | awk '{print \$2}' || true)"
fi

if [[ "\$have_version" == "\$want_version" ]]; then
  echo "  gost \$have_version already installed, skipping download"
else
  echo "  installing gost v\$want_version (current: \${have_version:-none})"
  curl -fsSL -o gost.tar.gz "$GOST_URL"
  tar -xzf gost.tar.gz
  rm -f gost.tar.gz LICENSE README*.md
  chmod +x gost
  ./gost -V
fi
REMOTE

# -------- step 3: write systemd unit --------
echo
echo "[3/5] writing systemd unit..."
EXEC_LINE="${INSTALL_DIR}/gost -L auto://0.0.0.0:${LISTEN_PORT} -F ${UPSTREAM_URL}"

# Build the unit content locally first, then ship via stdin so credentials
# never touch the SSH command line / remote shell history.
UNIT_CONTENT=$(cat <<EOF
[Unit]
Description=gost SOCKS5/HTTP forwarder (port ${LISTEN_PORT})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${EXEC_LINE}
Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF
)

UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

# Hash-compare to decide whether a restart is needed
NEW_HASH=$(printf '%s' "$UNIT_CONTENT" | sha256sum | awk '{print $1}')

printf '%s' "$UNIT_CONTENT" | ssh "${SSH_OPTS[@]}" "$RELAY" "
set -euo pipefail
tmp=\$(mktemp)
cat > \"\$tmp\"
chmod 600 \"\$tmp\"
old_hash=\$(sha256sum \"$UNIT_PATH\" 2>/dev/null | awk '{print \$1}' || echo none)
new_hash=\$(sha256sum \"\$tmp\" | awk '{print \$1}')
if [[ \"\$old_hash\" == \"\$new_hash\" ]] && systemctl is-enabled \"$SERVICE_NAME\" >/dev/null 2>&1; then
  rm -f \"\$tmp\"
  echo \"  unit unchanged (sha256 \${new_hash:0:12})\"
  echo \"UNIT_UNCHANGED\"
else
  mv \"\$tmp\" \"$UNIT_PATH\"
  chmod 600 \"$UNIT_PATH\"
  echo \"  unit written: $UNIT_PATH (sha256 \${new_hash:0:12})\"
  echo \"UNIT_CHANGED\"
fi
" | tee /tmp/.gost-deploy-unit.out >/dev/null

UNIT_STATE=$(grep -oE 'UNIT_(CHANGED|UNCHANGED)' /tmp/.gost-deploy-unit.out | tail -1 || echo UNIT_CHANGED)
sed 's/UNIT_\(CHANGED\|UNCHANGED\)//' /tmp/.gost-deploy-unit.out | sed '/^$/d'
rm -f /tmp/.gost-deploy-unit.out

# -------- step 4: enable + (re)start --------
echo
echo "[4/5] enabling service..."
if [[ "$UNIT_STATE" == "UNIT_CHANGED" ]]; then
  ssh_run "systemctl daemon-reload && systemctl enable --now '$SERVICE_NAME' && systemctl restart '$SERVICE_NAME'"
else
  ssh_run "systemctl enable '$SERVICE_NAME' >/dev/null 2>&1 || true; systemctl is-active '$SERVICE_NAME' >/dev/null || systemctl start '$SERVICE_NAME'"
fi
sleep 2
ssh_run "systemctl is-active '$SERVICE_NAME' && systemctl is-enabled '$SERVICE_NAME'" \
  | sed 's/^/  /'

# -------- step 5: verify --------
echo
echo "[5/5] verifying..."
ssh_run "ss -ltnp | awk -v p=':$LISTEN_PORT' '\$4 ~ p {print \"  listen ok: \" \$0; found=1} END{exit !found}'" \
  || { echo "  ERROR: port $LISTEN_PORT not listening" >&2; exit 1; }

echo "  --- HTTP via relay ---"
ssh_run "curl --proxy http://127.0.0.1:$LISTEN_PORT -sS --connect-timeout 10 --max-time 25 http://ip-api.com/json" \
  | sed 's/^/  /'
echo
echo "  --- SOCKS5 via relay ---"
ssh_run "curl -x socks5h://127.0.0.1:$LISTEN_PORT -sS --connect-timeout 10 --max-time 25 http://ip-api.com/json" \
  | sed 's/^/  /'

cat <<EOF

=== done ===
Clients on LAN can now configure:
  protocol : HTTP or SOCKS5
  host     : ${RELAY##*@}
  port     : ${LISTEN_PORT}
  auth     : none

Common ops:
  ssh ${RELAY} 'systemctl status  ${SERVICE_NAME}'
  ssh ${RELAY} 'systemctl restart ${SERVICE_NAME}'
  ssh ${RELAY} 'journalctl -u ${SERVICE_NAME} -f'
  ssh ${RELAY} 'tail -f ${LOG_FILE}'
EOF
```

## 手动逐步部署（理解原理用）

如果你想知道脚本到底在远端做了什么，或者环境有特殊性（要走跳板机、要 review 每一步），按下面手动执行。

### 1. 前置检查

```bash
ssh root@<RELAY_HOST> 'uname -a; arch; which systemctl curl tar'
```

需要 Linux + systemd，且能访问 `github.com` 拉 gost release。

### 2. 下载 gost

用 v2.x（`-L` / `-F` 语法稳定）。`linux_amd64` 替换为对应架构（`linux_arm64` / `linux_armv7` 等）。

```bash
ssh root@<RELAY_HOST> bash <<'REMOTE'
set -e
mkdir -p /root/tools/proxy/gost
cd /root/tools/proxy/gost
curl -sSL -o gost.tar.gz \
  "https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz"
tar -xzf gost.tar.gz
rm -f gost.tar.gz LICENSE README*.md
chmod +x gost
./gost -V    # 期望：gost 2.12.0 (go1.22.8 linux/amd64)
REMOTE
```

### 3. systemd unit

关键参数：

- `-L auto://0.0.0.0:10083` —— `auto` 监听嗅探首字节自动识别 HTTP / SOCKS4 / SOCKS5，**一个端口同时支持三种**；
- `-F socks5://…` —— 上游 SOCKS5，含账密；
- `Restart=on-failure` + `network-online.target` 保证开机自启 + 异常重连。

```bash
ssh root@<RELAY_HOST> bash <<'REMOTE'
cat > /etc/systemd/system/gost-proxy.service <<'EOF'
[Unit]
Description=gost SOCKS5/HTTP forwarder (10083 -> upstream)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/tools/proxy/gost
ExecStart=/root/tools/proxy/gost/gost \
  -L auto://0.0.0.0:10083 \
  -F socks5://<UPSTREAM_USER>:<UPSTREAM_PASS>@<UPSTREAM_HOST>:<UPSTREAM_PORT>
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/gost-proxy.log
StandardError=append:/var/log/gost-proxy.log

[Install]
WantedBy=multi-user.target
EOF
chmod 600 /etc/systemd/system/gost-proxy.service   # 含明文密码，权限收紧
systemctl daemon-reload
systemctl enable --now gost-proxy
systemctl status gost-proxy --no-pager | head -15
REMOTE
```

期望状态 `Active: active (running)`。

### 4. 验证（同时验三种入口）

```bash
# 服务器本机
ssh root@<RELAY_HOST> 'ss -ltnp | grep 10083; \
  curl -x socks5h://127.0.0.1:10083 -s --max-time 20 http://ip-api.com/json'

# 内网其它机器
curl --proxy http://<RELAY_HOST>:10083 -s --max-time 20 http://ip-api.com/json
curl --proxy http://<RELAY_HOST>:10083 --ssl-no-revoke -sI --max-time 20 https://www.google.com | head -1
curl -x socks5h://<RELAY_HOST>:10083 -s --max-time 20 http://ip-api.com/json
```

JSON 的 `query` 字段应是预期的上游出口 IP；HTTPS HEAD 应返回 `HTTP/2 200`（或 `301`）。

## 客户端配置（SmartProxy / SwitchyOmega）

| 字段 | 值 |
|---|---|
| 协议 | `HTTP` 或 `SOCKS5` 均可 |
| 主机 | 中转主机 IP |
| 端口 | `10083` |
| 用户名 / 密码 | **留空** |
| 代理 DNS（仅 SOCKS5） | 建议勾上（=`socks5h`，避免 DNS 泄漏） |

## 常用运维

```bash
systemctl status  gost-proxy        # 状态
systemctl restart gost-proxy        # 重启
systemctl stop    gost-proxy        # 停止
journalctl -u gost-proxy -f         # 跟踪日志
tail -f /var/log/gost-proxy.log     # 直接看日志文件
```

更换上游：编辑 unit 的 `-F` 参数 → `systemctl daemon-reload && systemctl restart gost-proxy`。或者直接重跑部署脚本（传新的 `UPSTREAM_URL`），脚本会自动检测内容变化并 restart。

## 加固建议（可选）

默认配置监听 `0.0.0.0:10083` 且**本地无认证**，意味着任何能路由到中转主机的客户端都能白嫖出口。如果不是完全可信的 LAN，按需选用：

1. **加本地认证**：把 `-L auto://...` 改成 `-L auto://localuser:localpass@0.0.0.0:10083`（SmartProxy 走 HTTP 模式才能传 `Proxy-Authorization`）；
2. **绑定特定网卡**：`-L auto://192.168.x.x:10083` 只监听内网网卡，外部接口不暴露；
3. **iptables 限源**：仅放行 LAN 网段
   ```bash
   iptables -A INPUT -p tcp --dport 10083 -s 192.168.0.0/16 -j ACCEPT
   iptables -A INPUT -p tcp --dport 10083 -j DROP
   ```
4. **凭据外置到 `EnvironmentFile`**（`/etc/gost-proxy.env`，权限 600）：
   ```ini
   [Service]
   EnvironmentFile=/etc/gost-proxy.env
   ExecStart=/root/tools/proxy/gost/gost -L auto://0.0.0.0:10083 -F ${UPSTREAM_URL}
   ```
   这样 `gost-proxy.service` 本身不含密码，便于纳入配置管理。

## FAQ

**Q：浏览器扩展导入 `socks5://user:pass@...` 报错或一直转圈？**
A：Chromium `chrome.proxy` API 不支持 SOCKS5 认证。用本中转方案，扩展只填 `<RELAY_HOST>:10083`，无需账密。

**Q：HTTPS 站点失败、`curl` 报 `CRYPT_E_REVOCATION_OFFLINE`？**
A：Windows schannel 吊销列表无法在线校验，与代理无关。`curl` 加 `--ssl-no-revoke`，浏览器一般直接能用。

**Q：URL 标签 `#SOCKS-出口X` 之类的 fragment 要不要保留？**
A：`#...` 是 URL fragment，仅当 UI 标签用。某些导入器会把 `#` 后内容误当成密码一部分，**导入前手动删除**最稳。

**Q：能不能 HTTP 和 SOCKS5 分开两个端口？**
A：可以，systemd 单元写两个 `-L`：
```
-L http://0.0.0.0:10084 -L socks5://0.0.0.0:10083 -F socks5://...
```
但 `auto://` 单端口已经覆盖大多数场景，更省事。
