#!/bin/sh

CACHE_DIR="/tmp/mnt/SD/webdav/.rclone_internal_cache"
LOG_FILE="/tmp/rclone_clean.log"

FIND="$(which find)"
DU="$(which du)"
RM="$(which rm)"
DATE="$(which date)"


{
echo "========================================"
echo "清理开始: $($DATE '+%Y-%m-%d %H:%M:%S')"


# 检查SD挂载
if ! mount | grep -q "/tmp/mnt/SD"; then
    echo "错误: SD未挂载"
    exit 0
fi


if [ ! -d "$CACHE_DIR" ]; then
    echo "缓存目录不存在"
    exit 0
fi


echo "缓存目录: $CACHE_DIR"

echo "清理前占用:"
$DU -sh "$CACHE_DIR" 2>/dev/null


echo "扫描缓存文件..."

# BusyBox兼容：删除超过1天未修改文件
$FIND "$CACHE_DIR" -type f -mtime +0 | while read FILE
do

    # 如果存在fuser，检测占用
    if command -v fuser >/dev/null 2>&1; then
        if fuser "$FILE" >/dev/null 2>&1; then
            echo "跳过占用文件: $FILE"
            continue
        fi
    fi


    echo "删除缓存: $FILE"
    $RM -f "$FILE"

done



echo "清理空目录..."

$FIND "$CACHE_DIR" -type d | while read DIR
do

    [ "$DIR" = "$CACHE_DIR" ] && continue

    if [ -z "$(ls -A "$DIR" 2>/dev/null)" ]; then
        echo "删除空目录: $DIR"
        rmdir "$DIR" 2>/dev/null
    fi

done



echo "清理后占用:"
$DU -sh "$CACHE_DIR" 2>/dev/null


echo "清理完成"

} >> "$LOG_FILE" 2>&1
