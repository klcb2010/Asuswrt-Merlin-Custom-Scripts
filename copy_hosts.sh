#!/bin/bash

# 源文件 URL 与科学上网插件冲突   科学上网的订阅等操作会覆盖 导致自定义hosts失效 
source_url="https://cors.isteed.cc/raw.githubusercontent.com/klcb2010/restart_wan-and-hosts-mod/main/hosts"

# 目标文件路径
target_file="/tmp/etc/hosts"

# 日志文件路径
log_file="/jffs/scripts/copy_hosts.log"
TMP_LOG_FILE="/jffs/scripts/copy_hosts.tmp"

# 记录脚本开始时间
start_time=$(date +%s)

# 检查日志文件是否存在，如果不存在则创建并设置权限
if [ ! -f "$log_file" ]; then
    touch "$log_file"
    chmod 777 "$log_file"
    echo "Log file $log_file created and permissions set to 777." >> "$log_file"
fi

# 计算七天前的 Unix 时间戳
cutoff_timestamp=$(( $(date +%s) - 7 * 24 * 60 * 60 ))

# 保留最近七天的日志记录
awk -v cutoff_timestamp="$cutoff_timestamp" '
    $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/ {
        timestamp_str = substr($0, 1, 19)
        timestamp = mktime(gensub(/[- :]/," ","g",timestamp_str))
        if (timestamp > cutoff_timestamp) print
    }
' "$log_file" > "$TMP_LOG_FILE" && mv "$TMP_LOG_FILE" "$log_file"

# 检查目标文件是否存在
if [ -f "$target_file" ]; then
    # 备份当前文件
    cp "$target_file" "$target_file.bak"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Backup of $target_file created as $target_file.bak." >> "$log_file"
    
    # 更改文件权限以便写入
    chmod 777 "$target_file"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Temporarily changed permissions of $target_file to 777 for updating." >> "$log_file"
fi

# 使用 curl 下载文件到目标路径
curl -o "$target_file" "$source_url"

# 检查下载操作是否成功
if [ $? -eq 0 ]; then
    # 现在修改 ss_rule_update.sh 中的 URL_MAIN 变量
    sed -i 's#^URL_MAIN.*#URL_MAIN="https://cors.isteed.cc/https%3A%2F%2Fraw.githubusercontent.com%2Fqxzg%2FActions%2F3.0%2Ffancyss_rules"#g' /koolshare/scripts/ss_rule_update.sh

    # 检查 sed 操作（这里只是简单地打印消息到日志）
    echo "$(date +'%Y-%m-%d %H:%M:%S') URL_MAIN in ss_rule_update.sh has been updated." >> "$log_file"

    # 还原文件权限
    chmod 644 "$target_file"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Restored permissions of $target_file to 644 after updating." >> "$log_file"

    # 添加新功能：重启dnsmasq服务
    killall -SIGHUP dnsmasq
    echo "$(date +'%Y-%m-%d %H:%M:%S') dnsmasq service restarted with SIGHUP signal." >> "$log_file"
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') Error occurred while downloading the file." >> "$log_file"
    exit 1
fi

# 记录脚本结束时间并计算执行时间
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "$(date +'%Y-%m-%d %H:%M:%S') Script executed in $duration seconds." >> "$log_file"

# 脚本结束
exit 0
