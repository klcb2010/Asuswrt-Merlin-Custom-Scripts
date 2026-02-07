#!/bin/sh
# clean_cron_logs.sh - 自动清理监控脚本日志（带 PID 检查）
# 版本 1.8 - 精确清理 /jffs/frpc/frpc.log

SCRIPT_VERSION="1.8"
TMP_LOG_DIR="/tmp"
FRPC_LOG="/jffs/frpc/frpc.log"
SELF_LOG="/tmp/clean_cron_logs.log"
RETENTION_DAYS=5
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

# 清理 /tmp 下指定日志文件
find "$TMP_LOG_DIR" -type f \( \
    -name "httpd_watch_cron.log" -o \
    -name "rclone_webdav.log" -o \
    -name "ss_rule_update.log" -o \
    -name "ss_online_update.log" \
\) -mtime +$RETENTION_DAYS -exec rm -f {} \; -exec log "已删除 {}" \;

# 精确清理 /jffs/frpc/frpc.log（按天数）
if [ -f "$FRPC_LOG" ] && [ $(find "$FRPC_LOG" -mtime +$RETENTION_DAYS) ]; then
    rm -f "$FRPC_LOG"
    log "已删除 $FRPC_LOG"
fi

# 清理自身日志（按天数）
if [ -f "$SELF_LOG" ] && [ $(find "$SELF_LOG" -mtime +$RETENTION_DAYS) ]; then
    rm -f "$SELF_LOG"
    log "已删除自身日志 $SELF_LOG"
fi

log "日志清理完成"

# 删除 PID 文件
rm -f "$PID_FILE"
