#!/bin/sh
# clean_cron_logs.sh - 内存保护型日志清理脚本 (简体中文版)
# 更新：同时清理 /tmp/ 和 /jffs/scripts/ 下的指定日志文件

LOG_DIR_TMP="/tmp"
LOG_DIR_JFFS="/jffs/scripts"
RETENTION_DAYS=7          # 保留天数：超过7天的直接删
MAX_SIZE_KB=2048          # 单个日志上限 2MB
TMP_FREE_MIN=10           # /tmp 剩余空间低于 10% 时强制清理
PID_FILE="/tmp/clean_cron_logs.pid"

log() {
    logger "[日志清理] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# PID 检查：防止脚本重叠运行
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$PID_FILE"

# 1. 空间预警检测：如果 /tmp 空间占用超过 90%，执行紧急清理
FREE_PERCENT=$(df -h "$LOG_DIR_TMP" | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$FREE_PERCENT" -gt 90 ]; then
    log "警告：/tmp 空间占用过高 ($FREE_PERCENT%)，执行紧急截断！"
    # 紧急模式：直接截断所有以 .log 结尾的文件
    for log_file in "$LOG_DIR_TMP"/*.log; do
        [ -f "$log_file" ] && : > "$log_file"
    done
fi

# 2. 定向清理名单（文件名，空格分隔）
LOG_FILES="\
rclone_webdav.log \
ipv6_sentinel.log \
ss_rule_update.log \
ss_online_update.log \
clean_cron_logs.log \
frpc.log \
frpc_start.log \
nat-start.log \
"

# 3. 清理 /tmp/ 下的日志
for f in $LOG_FILES; do
    FILE_PATH="$LOG_DIR_TMP/$f"
    if [ -f "$FILE_PATH" ]; then
        find "$LOG_DIR_TMP" -name "$f" -mtime +$RETENTION_DAYS -delete 2>/dev/null
        if [ -f "$FILE_PATH" ]; then
            FILE_SIZE=$(du -k "$FILE_PATH" | awk '{print $1}')
            if [ "$FILE_SIZE" -gt "$MAX_SIZE_KB" ]; then
                : > "$FILE_PATH"
                log "日志 $f 体积过大 ($FILE_SIZE KB)，已执行截断清空。"
            fi
        fi
    fi
done

# 4. 清理 /jffs/scripts/ 下的日志（新增）
for f in $LOG_FILES; do
    FILE_PATH="$LOG_DIR_JFFS/$f"
    if [ -f "$FILE_PATH" ]; then
        find "$LOG_DIR_JFFS" -name "$f" -mtime +$RETENTION_DAYS -delete 2>/dev/null
        if [ -f "$FILE_PATH" ]; then
            FILE_SIZE=$(du -k "$FILE_PATH" | awk '{print $1}')
            if [ "$FILE_SIZE" -gt "$MAX_SIZE_KB" ]; then
                : > "$FILE_PATH"
                log "日志 $f 体积过大 ($FILE_SIZE KB)，已执行截断清空。"
            fi
        fi
    fi
done

rm -f "$PID_FILE"
log "日志维护任务完成。"
