#!/bin/sh

# cron 用户
USER="klcb2010"

# 日志文件路径
LOG_FILE="/jffs/scripts/set_crontab.log"

# 延迟启动时间（秒），可以根据需要调整
DELAY_START=30

# 获取当前时间函数，格式 2026-01-11 11:22:33
now() {
    date +"%Y-%m-%d %H:%M:%S"
}

# 清空日志文件
echo "" > "$LOG_FILE"

# 记录脚本开始执行的时间
echo "$(now): set_crontab.sh start" >> "$LOG_FILE"

# 延迟启动，确保系统初始化完成
sleep $DELAY_START
echo "$(now): Delay of $DELAY_START seconds completed" >> "$LOG_FILE"

# cron 文件路径
CRON_FILE="/jffs/scripts/cron"
CRONTAB_FILE="/var/spool/cron/crontabs/$USER"

# 检查 CRON_FILE 是否存在，如果不存在则尝试创建
if [ ! -f "$CRON_FILE" ]; then
    touch "$CRON_FILE"
    if [ $? -eq 0 ]; then
        echo "$(now): Cron tasks file $CRON_FILE has been created." >> "$LOG_FILE"
        chmod 777 "$CRON_FILE"
        if [ $? -eq 0 ]; then
            echo "$(now): Cron tasks file permissions have been set to 777 (WARNING: insecure!)" >> "$LOG_FILE"
        else
            echo "$(now): Failed to set permissions for $CRON_FILE" >> "$LOG_FILE"
        fi
    else
        echo "$(now): Failed to create cron tasks file $CRON_FILE" >> "$LOG_FILE"
        exit 1
    fi
fi

# 如果 CRON_FILE 存在，则更新 crontab
if [ -f "$CRON_FILE" ]; then
    crontab -u $USER "$CRON_FILE"
    if [ $? -eq 0 ]; then
        echo "$(now): Cron tasks for $USER have been updated from $CRON_FILE" >> "$LOG_FILE"
    else
        echo "$(now): Failed to update cron tasks for $USER from $CRON_FILE" >> "$LOG_FILE"
    fi
else
    echo "$(now): Cron tasks file $CRON_FILE does not exist!" >> "$LOG_FILE"
fi

# 记录脚本执行完成的时间
echo "$(now): set_crontab.sh ok" >> "$LOG_FILE"
