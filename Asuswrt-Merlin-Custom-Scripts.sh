#!/bin/sh
# =====================================================
# 自动下载脚本、赋权限，并执行必要脚本

# 定义目录和文件URL
# 使用了反代加速，建议加上 -k 预防 SSL 报错
BASE_URL="https://ghfast.top/raw.githubusercontent.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/main"
DEST_DIR_SCRIPTS="/jffs/scripts"

# 创建目录
if [ ! -d "$DEST_DIR_SCRIPTS" ]; then
    mkdir -p "$DEST_DIR_SCRIPTS"
    chmod 755 "$DEST_DIR_SCRIPTS"
fi

# 下载文件并赋权限
download_and_chmod() {
    url="$1"
    dest="$2"
    echo "正在下载: $url"
    # -L 跟随重定向, -k 忽略证书(防止开机时间不同步), -s 静默模式
    curl -Lk -o "$dest" "$url"
    
    if [ $? -eq 0 ]; then
        # 修正换行符（防止Windows编辑污染），赋予 755 权限
        sed -i 's/\r$//' "$dest"
        chmod 755 "$dest"
        echo "成功并设权: $dest"
    else
        echo "错误: 无法下载 $url"
        return 1
    fi
}

# 文件列表
FILES="rclone_webdav.sh clean_logs.sh SSH_helper.sh rclone_clean_cache.sh rclone_webdav_check manage_backup.sh"

for file in $FILES; do
    download_and_chmod "$BASE_URL/$file" "$DEST_DIR_SCRIPTS/$file" || exit 1
done

# 执行必要脚本
# 注意：frpc_start.sh 建议在后台运行，避免阻塞主脚本
# echo "正在启动 frpc"
#sh "$DEST_DIR_SCRIPTS/frpc_start.sh" &

echo "所有操作已完成。"
