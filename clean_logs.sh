#!/bin/sh
# clean_logs.sh - 智能日志维护

SCRIPT_DIR="/jffs/scripts"
SELF_LOG="$SCRIPT_DIR/clean_logs.txt"
SELF_LOG_MAX_KB=1024
LOG_THRESHOLD_KB=10240

# ===== 白名单 =====
WHITELIST="/jffs/scripts/rclone_start.log"

# ===== 强制删除目录 =====
if [ -d "/tmp/mnt/SD/CNID" ]; then
    rm -rf /tmp/mnt/SD/CNID
fi

# 1. 自身日志维护
if [ -f "$SELF_LOG" ]; then
    size_kb=$(du -k "$SELF_LOG" | awk '{print $1}')
    if [ "${size_kb:-0}" -gt "$SELF_LOG_MAX_KB" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自身日志滚动重置" > "$SELF_LOG"
    fi
fi

# 2. 开始检查
echo "===== 检查开始 $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$SELF_LOG"

# 初始化统计变量
total_found=$(find /jffs /tmp -type f -name "*.log" 2>/dev/null | wc -l)
cleaned_count=0

# 3. 扫描并处理
find /jffs /tmp -type f -name "*.log" 2>/dev/null | while read -r file
do
    # 获取当前文件大小 (KB)
    f_size_kb=$(du -k "$file" | awk '{print $1}')
    
    # 逻辑 A: 白名单
    case "$WHITELIST" in
        *"$file"*)
            continue
        ;;
    esac

    # 逻辑 B: 超过阈值
    if [ "$f_size_kb" -gt "$LOG_THRESHOLD_KB" ]; then
        old_size_h=$(du -h "$file" | awk '{print $1}')
        : > "$file"
        echo "  [清理] $file ($old_size_h -> 0)" >> "$SELF_LOG"
        cleaned_count=$((cleaned_count + 1))
    fi
done

# 4. 总结汇报
if [ "$cleaned_count" -eq 0 ]; then
    echo "总结: 共扫描 $total_found 个日志，未发现超过 ${LOG_THRESHOLD_KB}KB 的文件，无需清理。" >> "$SELF_LOG"
else
    echo "总结: 共扫描 $total_found 个日志，已清理 $cleaned_count 个超标大文件。" >> "$SELF_LOG"
fi

echo "===== 检查结束 $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$SELF_LOG"
echo "" >> "$SELF_LOG"
