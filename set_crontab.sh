#!/bin/sh

# cron 用户
CRON_USER="klcb2010"

# 日志文件路径
LOG_FILE="/jffs/scripts/set_crontab.log"

# 延迟启动（秒）
DELAY_START=${DELAY_START:-5}

# 获取当前时间
now() {
    date +"%Y-%m-%d %H:%M:%S"
}

# 清空日志
: > "$LOG_FILE"
echo "$(now): set_crontab.sh start" >> "$LOG_FILE"

# 延迟启动
sleep $DELAY_START
echo "$(now): Delay of $DELAY_START seconds completed" >> "$LOG_FILE"

# cron 文件路径
CRON_FILE="/jffs/scripts/cron"

# 检查 cron 文件是否存在
if [ ! -f "$CRON_FILE" ]; then
    touch "$CRON_FILE"
    if [ $? -eq 0 ]; then
        echo "$(now): Cron tasks file $CRON_FILE has been created." >> "$LOG_FILE"
        chmod 600 "$CRON_FILE"
    else
        echo "$(now): Failed to create cron tasks file $CRON_FILE" >> "$LOG_FILE"
        exit 1
    fi
fi

# 更新 crontab
crontab -u $CRON_USER "$CRON_FILE" && \
echo "$(now): Cron tasks for $CRON_USER have been updated" >> "$LOG_FILE" || \
echo "$(now): Failed to update cron tasks for $CRON_USER" >> "$LOG_FILE"

echo "$(now): set_crontab.sh ok" >> "$LOG_FILE"
