#!/bin/sh
# ============================================================
# rclone_webdav.sh - Fix large file upload stream reset
# ============================================================
export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH

# ------------------------------
# Config Replace your port/user/pass
# ------------------------------
SHARE="/tmp/mnt/SD"
CACHE_DIR="/tmp/mnt/SD/webdav/.rclone_internal_cache"

USER="用户名"
CERT_DIR="/jffs/rclone_cert"
CERT="$CERT_DIR/cert.pem"
KEY="$CERT_DIR/key.pem"

WAN_PORT=8181
LAN_PORT=8180

WAN_PASS='密码外网'
LAN_PASS='密码内网'

# ==============================
# Init
# ==============================
mkdir -p "$SHARE" "$CACHE_DIR" "$CERT_DIR"

# ==============================
# SSL cert auto generate
# ==============================
if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$KEY" \
        -out "$CERT" \
        -days 3650 -nodes \
        -subj "/CN=router" >/dev/null 2>&1
    chmod 600 "$KEY"
    chmod 644 "$CERT"
fi

# ==============================
# Check port listening status
# ==============================
is_running() {
    netstat -lnt 2>/dev/null | grep -q ":$1 "
}

# ==============================
# Start WebDAV Instance
# ==============================
start_instance() {
    port=$1
    pass=$2
    tls=$3
    log="/tmp/rclone_${port}.log"

    if is_running "$port"; then
        echo "[OK] Port $port already running"
        return
    fi

    TLS=""
    [ "$tls" = "true" ] && TLS="--cert $CERT --key $KEY"

    echo "[START] WebDAV on port $port"

    nohup /opt/bin/rclone serve webdav "$SHARE" \
        --addr ":$port" \
        --user "$USER" \
        --pass "$pass" \
        $TLS \
        --server-read-timeout 600s \
        --server-write-timeout 600s \
        --dir-cache-time 1m \
        --poll-interval 1m \
        --vfs-cache-mode writes \
        --vfs-cache-max-age 1m \
        --vfs-cache-max-size 30G \
        --cache-dir "$CACHE_DIR" \
        --buffer-size 64M \
        --vfs-read-chunk-size 64M \
        --vfs-read-chunk-size-limit 512M \
        --exclude ".DS_Store" \
        --exclude "._*" \
        --exclude "*.tmp" \
        --exclude "*.part" \
        --exclude "CNID/*" \
        --no-modtime \
        --no-checksum \
        --log-level ERROR >> "$log" 2>&1 &
}

# ==============================
# Run two instances
# ==============================
start_instance $WAN_PORT "$WAN_PASS" true
start_instance $LAN_PORT "$LAN_PASS" false

# ==============================
# Status Print
# ==============================
echo "========================================"
echo "WebDAV SERVICE STATUS"
echo "----------------------------------------"
echo "WAN  : $WAN_PORT (HTTPS ENABLED)"
echo "LAN  : $LAN_PORT (HTTP ONLY)"
echo "CACHE: ENABLED, REFRESH INTERVAL 1MIN"
echo "TIMEOUT: 600S READ/WRITE CONNECTION TIMEOUT"
echo "EXCLUDE: CNID + SYSTEM TEMP FILES"
echo "========================================"

