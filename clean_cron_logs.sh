#!/bin/sh
# clean_cron_logs.sh - 自动清理监控脚本日志（带 PID 检查）

SCRIPT_VERSION="1.3"
LOG_DIR="/tmp"
RETENTION_DAYS=7
PID_FILE="/tmp/clean_cron_logs.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -------------------------------
# PID 检查 - 避免重复运行
# -------------------------------
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    log "清理脚本已在运行，退出"
    exit 0
fi

# 写入当前进程 PID
echo $$ > "$PID_FILE"

log "开始清理旧日志（保留最近 $RETENTION_DAYS 天）"

# 查找并删除超过 RETENTION_DAYS 的日志文件
find "$LOG_DIR" -type f \( \
    -name "httpd_watch_cron.log" -o \
    -name "rclone_webdav.log" -o \
    -name "ipv6_watchdog_cron.log" -o \
    -name "ss_rule_update.log" -o \
    -name "ss_online_update.log" -o \
    -name "letsencrypt.log" \
\) -mtime +$RETENTION_DAYS -exec rm -f {} \; -exec log "已删除 {}" \;

log "日志清理完成"

# 删除 PID 文件
rm -f "$PID_FILE"
