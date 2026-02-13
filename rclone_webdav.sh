#!/bin/sh

# 1. 等待环境就绪 (硬盘挂载 & 证书生成)
# 循环检查 40 秒，直到系统生成证书或超时
TIMER=0
while [ ! -f "/etc/cert.pem" ] && [ $TIMER -lt 40 ]; do
    sleep 2
    TIMER=$((TIMER + 2))
done

# 2. 检查 rclone 是否已经在跑
if pidof rclone >/dev/null 2>&1; then
    logger "rclone WebDAV 已经在运行中"
    exit 0
fi

# 3. 启动 WebDAV (使用你的原版指令)
# 请务必手动修改下面的 用户名 和 密码
nohup /opt/bin/rclone serve webdav /tmp/mnt/SD/ \
  --addr 0.0.0.0:8181 \
  --user 独立用户名 \
  --pass 密码 \
  --cert /etc/cert.pem \
  --key /etc/key.pem \
  --vfs-cache-mode writes \
  > "/tmp/rclone.log" 2>&1 &

logger "rclone WebDAV 已在 8181 端口启动"
