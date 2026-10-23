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
