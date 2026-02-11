#!/bin/sh
# IPv6 Sentinel - 检测 odhcp6c 进程 + IPv6 连通性，自动修复

# 日志文件放在脚本同目录（/jffs/scripts/）
V6_LOG="/jffs/scripts/ipv6_sentinel.log"

log_v6() {
    echo "[$(date '+%m-%d %H:%M:%S')] $1" >> "$V6_LOG"
}

LOCKFILE="/tmp/ipv6_sentinel.lock"
[ -e ${LOCKFILE} ] && kill -0 $(cat ${LOCKFILE}) 2>/dev/null && exit 0
echo $$ > ${LOCKFILE}

do_fix() {
    log_v6 "检测到全局断网，尝试强制光猫重发前缀..."
   
    # 1. 彻底杀掉旧进程
    killall -9 odhcp6c 2>/dev/null
    sleep 2
   
    # 2. 触发系统 IPv6 栈重置
    service restart_ipv6
    sleep 3
   
    # 3. 强制带参数启动 (针对电信光猫挂起优化)
    WAN_IF=$(nvram get ipv6_ifname)
    [ -z "$WAN_IF" ] && WAN_IF="eth0"
   
    log_v6 "手动拉起 odhcp6c 对接接口 $WAN_IF ..."
    # 增加 -R 参数重置，强制要求光猫重新分配
    odhcp6c -df -R -s /tmp/dhcp6c -N try "$WAN_IF" &
   
    sleep 5
    # 4. 强制刷新局域网，让电脑重获新地址
    service restart_dnsmasq
    log_v6 "深度修复完成，请检查电脑连通性。"
}

# 1. 进程检查
if ! pidof odhcp6c > /dev/null; then
    log_v6 "警告: odhcp6c 丢失，正在拉起..."
    do_fix
    rm -f ${LOCKFILE}
    exit 0
fi

# 2. 连通性检测 (只要 Ping 不通，就算进程在也要修)
if ! ping6 -c 1 -W 2 2400:3200::1 > /dev/null 2>&1; then
    # 再次确认 IPv4 是否正常 (排除光猫死机或欠费)
    if ping -c 1 -W 2 114.114.114.114 > /dev/null 2>&1; then
        log_v6 "IPv6 假死(有地址无流量)，执行深度修复..."
        do_fix
    else
        log_v6 "检测到物理连通性异常(IPv4也不通)，跳过 IPv6 修复。"
    fi
fi

rm -f ${LOCKFILE}
