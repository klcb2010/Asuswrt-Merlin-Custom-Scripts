#!/bin/sh
# httpd_watch v3.1 - httpd / HTTPS / SSH 公钥监控
SCRIPT_VERSION="3.1"

LOG_FILE="/tmp/httpd_watch.log"
DDNS_HTTPS="https://你的用户名.asuscomm.com:8443"

# SSH 公钥内容
PUBKEY="你的公钥"
AUTHORIZED_KEYS="/jffs/.ssh/authorized_keys"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

# -------------------------------
# 获取当前 IPv6 地址
# -------------------------------
CUR_IP=$(ip -6 addr show dev eth0 scope global 2>/dev/null | awk '/inet6 / {print $2}' | cut -d/ -f1 | head -n1)

# -------------------------------
# HTTPS / 证书测试
# -------------------------------
https_ok=1
if [ -n "$CUR_IP" ]; then
    TEST_URL="https://[$CUR_IP]:8443"
    curl -s -I -k --connect-timeout 10 --max-time 20 "$TEST_URL" >/dev/null 2>&1 || https_ok=0
else
    https_ok=0
fi

# -------------------------------
# httpd 检查
# -------------------------------
HTTPD_PID=$(pidof httpd)

if [ $https_ok -eq 0 ]; then
    log "证书/HTTPS 测试失败 → 重启 httpd"
    service restart_httpd
    sleep 2
    log "httpd 已重启"
elif [ -z "$HTTPD_PID" ]; then
    log "httpd 进程不存在 → 重启 httpd"
    service restart_httpd
    sleep 2
    log "httpd 已重启"
else
    log "httpd 状态正常"
fi

# -------------------------------
# SSH 公钥检查与加载
# -------------------------------
# 持久化目录
mkdir -p /jffs/.ssh
echo "$PUBKEY" > "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

# 内存目录，供 Dropbear 使用
mkdir -p /tmp/home/root/.ssh
cp "$AUTHORIZED_KEYS" /tmp/home/root/.ssh/
chmod 600 /tmp/home/root/.ssh/authorized_keys

# 检查 sshd 是否加载公钥
if ! sshd -T 2>/dev/null | grep -q "authorized_keys"; then
    log "SSH 公钥未生效 → 重启 sshd"
    service restart_sshd
    sleep 2
    log "sshd 已重启"
else
    log "SSH 公钥状态正常"
fi

# -------------------------------
# 完成
# -------------------------------
log "httpd_watch 脚本运行完成 v$SCRIPT_VERSION"
