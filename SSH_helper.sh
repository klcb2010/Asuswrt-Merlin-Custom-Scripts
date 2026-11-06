#!/bin/sh
# SSH_helper.sh
#
# SSH_helper V13
#
# 功能：
# 1. 注入指定SSH公钥防重复写入，权限加固
# 2. 固化nvram地区码US/01、降级校验放行DOWNGRADE_CHECK_PASS=1
# 3. 智能SD磁盘挂载修复逻辑
# 4. 开机后台启动rclone webdav服务
# 5. IPv4+IPv6批量放行指定防火墙端口8180/8181/2525
# 6. IPv6长地址优先：
#    ① 自动识别eth0上的全局IPv6 /128地址
#    ② 自动识别正常的全局IPv6 /64地址
#    ③ 将所有未deprecated的/128地址设置为preferred_lft 0
#    ④ 持续监测IPv6地址及出站源地址
#    ⑤ IPv6前缀变化或/128重新出现时自动处理
#    ⑥ 不删除任何IPv6地址，不改变IPv6穿透模式
#
# ============================================================

# ================= 配置区 =================

SSH_KEY=''

SSH_DIR="/root/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"

TARGET_TERRITORY="US/01"

# SD设备
SD_DEV="/dev/sda5"

# 标准挂载
SD_MOUNT="/tmp/mnt/SD"

# 异常挂载
SD_ERROR_MOUNT="/tmp/mnt/SD(1)"

# 防火墙端口
FW_PORTS="8180 8181 2525"

# 等待磁盘时间
DISK_WAIT_SEC=30

# IPv6接口
IPV6_IF="eth0"

# IPv6后台监测间隔
IPV6_MONITOR_INTERVAL=60

# IPv6监测PID文件
IPV6_PID_FILE="/tmp/SSH_helper_ipv6_monitor.pid"

# ================= 日志 =================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/ssh_helper.log"

log()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null
}

# ================= 查找ip命令 =================

IP_CMD=""

find_ip_command()
{
    IP_CMD="$(command -v ip 2>/dev/null)"

    if [ -z "${IP_CMD}" ] && [ -x /sbin/ip ]; then
        IP_CMD="/sbin/ip"
    fi

    if [ -z "${IP_CMD}" ] && [ -x /usr/sbin/ip ]; then
        IP_CMD="/usr/sbin/ip"
    fi

    if [ -z "${IP_CMD}" ] && [ -x /bin/ip ]; then
        IP_CMD="/bin/ip"
    fi

    if [ -z "${IP_CMD}" ] && [ -x /usr/bin/ip ]; then
        IP_CMD="/usr/bin/ip"
    fi

    if [ -n "${IP_CMD}" ]; then
        log "找到ip命令：${IP_CMD}"
        return 0
    fi

    log "未找到ip命令"
    return 1
}

# ================= 等待磁盘 =================

wait_disk_ready()
{
    count=0

    log "等待磁盘设备 ${SD_DEV} 就绪"

    while [ ! -b "${SD_DEV}" ] && [ "${count}" -lt "${DISK_WAIT_SEC}" ]
    do
        sleep 1
        count=$((count + 1))
    done

    if [ ! -b "${SD_DEV}" ]; then
        log "未发现 ${SD_DEV}，跳过SD处理"
        return 1
    fi

    log "检测到磁盘 ${SD_DEV}"
    return 0
}

# ================= SD挂载修复 =================

mount_sd_fix()
{
    wait_disk_ready || return 0

    log "===== 开始检测SD挂载状态 ====="

    ERR_DEV=$(mount 2>/dev/null | awk -v m="${SD_ERROR_MOUNT}" '$3 == m {print $1; exit}')
    NORMAL_DEV=$(mount 2>/dev/null | awk -v m="${SD_MOUNT}" '$3 == m {print $1; exit}')

    # 情况1：存在SD(1)
    if [ -n "${ERR_DEV}" ]; then
        log "发现异常挂载 ${SD_ERROR_MOUNT}"
        log "真实设备 ${ERR_DEV}"

        if ! umount "${SD_ERROR_MOUNT}" 2>/dev/null; then
            log "普通卸载失败，尝试懒卸载"
            umount -l "${SD_ERROR_MOUNT}" 2>/dev/null
        fi

        if mount 2>/dev/null | grep -q " ${SD_MOUNT} "; then
            umount "${SD_MOUNT}" 2>/dev/null || umount -l "${SD_MOUNT}" 2>/dev/null
        fi

        if [ -d "${SD_MOUNT}" ]; then
            rmdir "${SD_MOUNT}" 2>/dev/null || log "标准挂载目录非空，跳过删除"
        fi

        if [ -d "${SD_ERROR_MOUNT}" ]; then
            if mv "${SD_ERROR_MOUNT}" "${SD_MOUNT}" 2>/dev/null; then
                log "挂载目录 SD(1) 已恢复为 SD"
            else
                log "目录重命名失败，创建新挂载点"
                mkdir -p "${SD_MOUNT}"
            fi
        else
            mkdir -p "${SD_MOUNT}"
        fi

        log "重新挂载 ${ERR_DEV} -> ${SD_MOUNT}"

        if mount "${ERR_DEV}" "${SD_MOUNT}" 2>/dev/null; then
            log "SD修复完成 ${ERR_DEV} -> ${SD_MOUNT}"
        else
            log "SD重新挂载失败"
        fi

        return 0
    fi

    # 情况2：磁盘存在，但没有任何挂载
    if [ -z "${NORMAL_DEV}" ]; then
        log "检测到磁盘但没有标准SD挂载"

        mkdir -p "${SD_MOUNT}"

        if mount "${SD_DEV}" "${SD_MOUNT}" 2>/dev/null; then
            log "SD预挂载成功"
        else
            log "SD预挂载失败"
        fi

        return 0
    fi

    # 情况3：正常
    log "SD已经正常挂载，无需处理"
}

# ================= IPv6后台监测任务 =================

ipv6_monitor_loop()
{
    log "IPv6后台监测任务启动，接口：${IPV6_IF}"

    LAST_STATUS=""

    while :
    do
        IPV6_ADDRS=$("${IP_CMD}" -6 addr show dev "${IPV6_IF}" scope global 2>/dev/null)

        # 获取正常的/64长地址
        LONG_ADDR=$(echo "${IPV6_ADDRS}" | awk '
            $1 == "inet6" &&
            $2 ~ /\/64$/ &&
            $0 !~ /temporary|deprecated|tentative/ {
                print $2
                exit
            }
        ')

        if [ -z "${LONG_ADDR}" ]; then
            if [ "${LAST_STATUS}" != "no_long" ]; then
                log "IPv6监测：尚未发现可用的/64长地址，继续等待"
                LAST_STATUS="no_long"
            fi

            sleep "${IPV6_MONITOR_INTERVAL}"
            continue
        fi

        LONG_IP="${LONG_ADDR%%/*}"

        # 获取所有尚未deprecated的/128地址
        SHORT_ADDRS=$(echo "${IPV6_ADDRS}" | awk '
            $1 == "inet6" &&
            $2 ~ /\/128$/ &&
            $0 !~ /deprecated|tentative/ {
                print $2
            }
        ')

        # 逐个处理/128地址
        for SHORT_ADDR in ${SHORT_ADDRS}
        do
            if "${IP_CMD}" -6 addr change "${SHORT_ADDR}" dev "${IPV6_IF}" preferred_lft 0 2>/dev/null; then
                log "IPv6短地址已设置为Deprecated：${SHORT_ADDR}"
            else
                log "IPv6短地址调整失败：${SHORT_ADDR}"
            fi
        done

        # 检查实际出站源地址
        TEST_ROUTE=$("${IP_CMD}" -6 route get 240e:4a:4400:3::167 2>/dev/null)

        TEST_SRC=$(echo "${TEST_ROUTE}" | awk '
            {
                for (i = 1; i <= NF; i++) {
                    if ($i == "src") {
                        print $(i+1)
                        exit
                    }
                }
            }
        ')

        if [ "${TEST_SRC}" = "${LONG_IP}" ]; then
            if [ "${LAST_STATUS}" != "success:${LONG_IP}" ]; then
                log "IPv6验证成功：出站源地址使用长地址 ${LONG_IP}"
                LAST_STATUS="success:${LONG_IP}"
            fi
        else
            if [ -n "${TEST_SRC}" ]; then
                if [ "${LAST_STATUS}" != "mismatch:${TEST_SRC}" ]; then
                    log "IPv6出站源地址暂未切换：${TEST_SRC}"
                    LAST_STATUS="mismatch:${TEST_SRC}"
                fi
            else
                if [ "${LAST_STATUS}" != "no_route" ]; then
                    log "IPv6暂时无法获取出站源地址，继续监测"
                    LAST_STATUS="no_route"
                fi
            fi
        fi

        sleep "${IPV6_MONITOR_INTERVAL}"
    done
}

# ================= 启动IPv6后台监测 =================

start_ipv6_monitor()
{
    log "===== 检查IPv6后台监测任务 ====="

    find_ip_command || return 1

    # 检查已有监测进程
    if [ -f "${IPV6_PID_FILE}" ]; then
        OLD_PID=$(cat "${IPV6_PID_FILE}" 2>/dev/null)

        case "${OLD_PID}" in
            ''|*[!0-9]*)
                OLD_PID=""
                ;;
        esac

        if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
            log "IPv6后台监测任务已运行，PID：${OLD_PID}"
            return 0
        fi

        rm -f "${IPV6_PID_FILE}"
    fi

    # 后台启动监测任务
    ipv6_monitor_loop >/dev/null 2>&1 &
    MONITOR_PID=$!

    echo "${MONITOR_PID}" > "${IPV6_PID_FILE}"

    sleep 1

    if kill -0 "${MONITOR_PID}" 2>/dev/null; then
        log "IPv6后台监测任务已启动，PID：${MONITOR_PID}"
        log "监测间隔：${IPV6_MONITOR_INTERVAL}秒"
    else
        rm -f "${IPV6_PID_FILE}"
        log "IPv6后台监测任务启动失败"
        return 1
    fi

    return 0
}

# ================= SSH公钥注入 =================

install_ssh_key()
{
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}" 2>/dev/null

    touch "${AUTH_FILE}"
    chmod 600 "${AUTH_FILE}" 2>/dev/null

    if [ -n "${SSH_KEY}" ] && [ "${SSH_KEY}" != "此处替换为完整SSH公钥" ]; then
        if ! grep -Fqx "${SSH_KEY}" "${AUTH_FILE}" 2>/dev/null; then
            echo "${SSH_KEY}" >> "${AUTH_FILE}"
            log "SSH公钥写入完成"
        else
            log "SSH公钥已存在"
        fi
    else
        log "SSH_KEY为空或未替换，跳过公钥写入"
    fi
}

# ================= NVRAM设置 =================

set_nvram()
{
    NVRAM_CHANGED=0

    CURRENT_TERR=$(nvram get territory_code 2>/dev/null)
    [ -z "${CURRENT_TERR}" ] && CURRENT_TERR="unset"

    if [ "${CURRENT_TERR}" != "${TARGET_TERRITORY}" ]; then
        nvram set territory_code="${TARGET_TERRITORY}"
        NVRAM_CHANGED=1
        log "territory_code 更新 ${CURRENT_TERR} -> ${TARGET_TERRITORY}"
    fi

    CURRENT_DOWNGRADE=$(nvram get DOWNGRADE_CHECK_PASS 2>/dev/null)
    [ -z "${CURRENT_DOWNGRADE}" ] && CURRENT_DOWNGRADE="unset"

    if [ "${CURRENT_DOWNGRADE}" != "1" ]; then
        nvram set DOWNGRADE_CHECK_PASS="1"
        NVRAM_CHANGED=1
        log "DOWNGRADE_CHECK_PASS 更新 ${CURRENT_DOWNGRADE} -> 1"
    fi

    if [ "${NVRAM_CHANGED}" -eq 1 ]; then
        nvram commit
        log "NVRAM已保存"
    else
        log "NVRAM无需修改"
    fi
}

# ================= rclone启动 =================

start_rclone()
{
    if pidof rclone >/dev/null 2>&1; then
        log "rclone 已在运行"
        return 0
    fi

    if command -v pgrep >/dev/null 2>&1; then
        if pgrep -f "rclone_webdav.sh" >/dev/null 2>&1; then
            log "rclone_webdav.sh 已在运行"
            return 0
        fi
    fi

    if [ -f "/jffs/scripts/rclone_webdav.sh" ]; then
        /bin/sh /jffs/scripts/rclone_webdav.sh >/dev/null 2>&1 &
        log "rclone_webdav.sh 后台启动"
    else
        log "未找到 /jffs/scripts/rclone_webdav.sh"
    fi
}

# ================= 防火墙端口放行 =================

allow_port()
{
    PORT="$1"

    # IPv4
    if ! iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null; then
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
        log "防火墙放行TCP端口 ${PORT} (IPv4)"
    else
        log "端口 ${PORT} (IPv4) 已放行"
    fi

    # IPv6
    if command -v ip6tables >/dev/null 2>&1; then
        if ! ip6tables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null; then
            ip6tables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
            log "防火墙放行TCP端口 ${PORT} (IPv6)"
        fi
    fi
}

# ================= 防火墙规则持久化 =================

ensure_firewall_persist()
{
    FW_START="/jffs/scripts/firewall-start"

    mkdir -p /jffs/scripts

    if [ ! -f "${FW_START}" ]; then
        cat > "${FW_START}" << 'FWEOF'
#!/bin/sh
# Auto-generated by SSH_helper.sh
FWEOF
        chmod +x "${FW_START}"
    fi

    for port in ${FW_PORTS} 9998 9999
    do
        if ! grep -q "dport ${port}" "${FW_START}" 2>/dev/null; then
            cat >> "${FW_START}" << FWEOF
# Port ${port} (added by SSH_helper)
iptables -C INPUT -p tcp --dport ${port} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -C INPUT -p tcp --dport ${port} -j ACCEPT 2>/dev/null || ip6tables -I INPUT -p tcp --dport ${port} -j ACCEPT
fi
FWEOF
            log "已将端口 ${port} 写入 firewall-start 持久化"
        fi
    done
}

# ================= 主入口 =================

log "================================================"
log "SSH_helper V13 启动"
log "运行路径 ${SCRIPT_DIR}"
log "日志文件 ${LOG_FILE}"
log "================================================"

# 1 SD修复
mount_sd_fix

# 2 SSH
install_ssh_key

# 3 NVRAM
set_nvram

# 4 启动IPv6后台持续监测
start_ipv6_monitor

# 5 rclone
start_rclone

# 6 防火墙（运行时放行）
for port in ${FW_PORTS}
do
    allow_port "${port}"
done

# 7 防火墙规则持久化
ensure_firewall_persist

log "================================================"
log "SSH_helper V13 执行完成"
log "================================================"

exit 0
