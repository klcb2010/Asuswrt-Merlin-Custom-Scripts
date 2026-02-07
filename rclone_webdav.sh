#!/bin/sh

sleep 5

LOG_FILE="/tmp/rclone.log"

# 检查 rclone 是否已经在跑
if pidof rclone >/dev/null 2>&1; then
    logger "rclone WebDAV already running"
    exit 0
fi

# 启动 WebDAV
nohup /opt/bin/rclone serve webdav /tmp/mnt/SD/ \
  --addr 0.0.0.0:8181 \
  --user 字母数字 \
  --pass 字母数字 \
  --cert /etc/cert.pem \
  --key /etc/key.pem \
  > "$LOG_FILE" 2>&1 &

logger "rclone WebDAV started on 8181"
