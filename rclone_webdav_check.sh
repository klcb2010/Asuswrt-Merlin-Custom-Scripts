#!/bin/sh
# rclone_webdav_check.sh 10min cycle guard script
export PATH=/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin

LAN_PORT=8180
WAN_PORT=8181
SHARE="/tmp/mnt/SD"
CACHE_DIR="${SHARE}/webdav/.rclone_internal_cache"

# Check if port is listening
port_listen_ok() {
    netstat -lnt 2>/dev/null | grep -q ":$1 "
}

# Check rclone process exists
proc_exist() {
    ps -w | grep -v grep | grep -q "rclone serve webdav"
}

# Clean expired cache files
clean_old_cache() {
    find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null
}

echo "===== Start WebDAV Check ====="
NEED_RESTART=0
if ! proc_exist; then
    echo "Detect: rclone process missing"
    NEED_RESTART=1
else
    echo "Detect: rclone process running"
    if ! port_listen_ok $LAN_PORT; then
        echo "Detect: LAN port $LAN_PORT offline"
        NEED_RESTART=1
    fi
    if ! port_listen_ok $WAN_PORT; then
        echo "Detect: WAN port $WAN_PORT offline"
        NEED_RESTART=1
    fi
fi

# 兼容BusyBox test 判断
if test $NEED_RESTART -eq 1; then
    echo "Action: Restart all rclone service"
    killall rclone 2>/dev/null
    sleep 1
    clean_old_cache
    /bin/sh /jffs/scripts/rclone_webdav.sh
else
    echo "Action: All services normal, skip restart"
fi
echo "===== Check Finished ====="
