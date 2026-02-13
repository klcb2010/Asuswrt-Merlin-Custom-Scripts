#!/bin/sh
# =====================================================
# restart_wan-cron-ss.sh
# 自动下载脚本、赋权限，并执行必要脚本
# sh/ash 兼容版，避免 unexpected "(" 错误
# =====================================================

# 定义目录和文件URL
BASE_URL="https://cors.isteed.cc/raw.githubusercontent.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/main"
DEST_DIR_SCRIPTS="/jffs/scripts"

# 创建目标目录（如果不存在）并赋权限
mkdir -p "$DEST_DIR_SCRIPTS" || {
    echo "Error: Failed to create directory $DEST_DIR_SCRIPTS"
    exit 1
}
chmod 777 "$DEST_DIR_SCRIPTS" || {
    echo "Error: Failed to assign permissions to $DEST_DIR_SCRIPTS"
    exit 1
}

# 下载文件并赋权限（兼容 sh）
download_and_chmod() {
    url="$1"
    dest="$2"
    echo "Downloading $url → $dest ..."
    curl -L -o "$dest" "$url" || {
        echo "Error: Failed to download $url"
        exit 1
    }
    chmod 777 "$dest" || {
        echo "Error: Failed to set permissions for $dest"
        exit 1
    }
    echo "Downloaded and set permissions: $dest"
}

# 执行脚本并记录日志
execute_script() {
    script="$1"
    echo "Executing $script..."
    sh "$script" || {
        echo "Error: $script failed with exit code $?"
        exit 1
    }
    echo "$script executed successfully."
}

# 文件列表（用空格分隔，sh 兼容  开启ipv6再添加 httpd_watch.sh ipv6_watchdog.sh
FILES="ss_rule_update.sh ss_online_update.sh cron set_territory.sh rclone_webdav.sh  frpc_start.sh   ipv6_sentinel.sh clean_cron_logs.sh"

# 下载并赋权限
for file in $FILES; do
    download_and_chmod "$BASE_URL/$file" "$DEST_DIR_SCRIPTS/$file"
done

# 执行必要脚本
execute_script "$DEST_DIR_SCRIPTS/set_crontab.sh"

echo "All scripts downloaded, permissions set, and required scripts executed successfully."
