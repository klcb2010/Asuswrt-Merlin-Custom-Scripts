#!/bin/sh
# SSH_helper.sh
# 功能：
# 1. 注入指定SSH公钥防重复写入，权限加固
# 2. 固化nvram地区码US/01、降级校验放行DOWNGRADE_CHECK_PASS=1
# 3. 智能双磁盘挂载修复逻辑（优先按LABEL识别）：
#    - LABEL="SD"  → 挂载为 /tmp/mnt/SD   （实际为 tntfs）
#    - LABEL="SF"  → 挂载为 /tmp/mnt/SF   （实际为 ext4）
# ① 最长等待90秒识别USB/SD磁盘设备
# ② 检测到异常挂载 SD(1)/SD(2)/SF(1)/SF(2) 等自动卸载清理并重挂载标准目录
# ③ 清理残留空挂载点目录，防止系统生成 (1)/(2)
# ④ 磁盘已识别但无对应标准挂载时，提前手动挂载标准目录
# ⑤ 正常存在标准挂载时直接跳过，不干扰原生自动挂载
# 4. 开机延迟120秒后台启动rclone webdav服务
# 5. IPv4+IPv6批量放行指定防火墙端口8180/8181/2525
# 使用说明：
# 1. 放入/jffs/scripts/SSH_helper.sh，chmod +x 赋予执行权限
# 2. 在 /jffs/.koolshare/init.d/V01softok.sh  内替换start模块  详见本项目首页


# ================= 配置区 =================
SSH_KEY='公钥'
SSH_DIR="/root/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"
TARGET_TERRITORY="US/01"
# 标准挂载点
SD_MOUNT="/tmp/mnt/SD"
SF_MOUNT="/tmp/mnt/SF"
# 防火墙端口
FW_PORTS="8180 8181 2525"
# 等待磁盘时间
DISK_WAIT_SEC=90
# ================= 日志 =================
SCRIPT_DIR="/jffs/scripts"
LOG_FILE="${SCRIPT_DIR}/ssh_helper.log"
mkdir -p "${SCRIPT_DIR}"
log()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}
# ================= 工具函数 =================
# 兼容方式提取 LABEL（应对残缺 blkid）
get_label()
{
    DEV="$1"
    [ -b "${DEV}" ] || { echo ""; return; }
    blkid "${DEV}" 2>/dev/null | sed -n 's/.*LABEL="\([^"]*\)".*/\1/p'
}
# 判断路径是否为挂载点
is_mounted()
{
    mount 2>/dev/null | grep -q " $1 "
}
# 安全卸载
safe_umount()
{
    MP="$1"
    if is_mounted "${MP}"; then
        log "卸载 ${MP}"
        umount "${MP}" 2>/dev/null || umount -l "${MP}" 2>/dev/null
    fi
}
# 清理残留空目录（防止生成 (1)/(2)）
clean_stale_dir()
{
    DIR="$1"
    if [ -d "${DIR}" ] && ! is_mounted "${DIR}"; then
        log "清理残留空目录 ${DIR}"
        rmdir "${DIR}" 2>/dev/null || rm -rf "${DIR}" 2>/dev/null
    fi
}
# 扫描并识别 SD / SF 设备（优先 LABEL）
discover_devices()
{
    SD_DEV=""
    SF_DEV=""
    for dev in /dev/sd*[0-9] /dev/sd[a-z]; do
        [ -b "${dev}" ] || continue
        label=$(get_label "${dev}")
        [ -z "${label}" ] && continue
        case "${label}" in
            SD)
                if [ -z "${SD_DEV}" ]; then
                    SD_DEV="${dev}"
                    log "识别到 LABEL=SD 设备: ${dev} → 将作为 SD"
                fi
                ;;
            SF)
                if [ -z "${SF_DEV}" ]; then
                    SF_DEV="${dev}"
                    log "识别到 LABEL=SF 设备: ${dev} → 将作为 SF"
                fi
                ;;
        esac
    done
    # 兜底：从已有挂载反查
    if [ -z "${SD_DEV}" ]; then
        SD_DEV=$(mount 2>/dev/null | awk '/\/tmp\/mnt\/SD/ {print $1; exit}')
        [ -n "${SD_DEV}" ] && log "通过已有挂载兜底找到 SD 设备: ${SD_DEV}"
    fi
    if [ -z "${SF_DEV}" ]; then
        SF_DEV=$(mount 2>/dev/null | awk '/\/tmp\/mnt\/SF/ {print $1; exit}')
        [ -n "${SF_DEV}" ] && log "通过已有挂载兜底找到 SF 设备: ${SF_DEV}"
    fi
}
# ================= 磁盘挂载修复 =================
# 单盘通用修复函数
mount_fix_one()
{
    NAME="$1"          # SD 或 SF
    DEV="$2"           # 对应设备
    NORMAL="$3"        # 标准挂载点 /tmp/mnt/SD 或 /tmp/mnt/SF
    log "===== 检测 ${NAME} 挂载状态 ====="
    # 1. 先处理所有异常挂载点（SD(1)、SD(2)、SF(1)、SF(2)...）
    for mp in /tmp/mnt/${NAME}\(*\); do
        [ -e "${mp}" ] || continue
        if is_mounted "${mp}"; then
            ERR_DEV=$(mount 2>/dev/null | awk -v m="${mp}" '$3 == m {print $1; exit}')
            log "发现异常挂载 ${mp} (设备: ${ERR_DEV})"
            safe_umount "${mp}"
            clean_stale_dir "${mp}"
            # 如果还没有标准挂载，就用这个设备挂到标准位置
            if [ -n "${ERR_DEV}" ] && [ -b "${ERR_DEV}" ] && ! is_mounted "${NORMAL}"; then
                mkdir -p "${NORMAL}"
                log "将异常设备 ${ERR_DEV} 重新挂载到 ${NORMAL}"
                if mount "${ERR_DEV}" "${NORMAL}" 2>/dev/null; then
                    log "${NAME} 从异常挂载修复完成"
                    return 0
                else
                    log "${NAME} 重新挂载失败"
                fi
            fi
        else
            # 目录存在但不是挂载点，直接清理
            clean_stale_dir "${mp}"
        fi
    done
    # 2. 清理标准挂载点如果是空目录
    clean_stale_dir "${NORMAL}"
    # 3. 检查是否已经正常挂载
    if is_mounted "${NORMAL}"; then
        NORMAL_DEV=$(mount 2>/dev/null | awk -v m="${NORMAL}" '$3 == m {print $1; exit}')
        log "${NAME} 已正常挂载 ${NORMAL_DEV} → ${NORMAL}"
        return 0
    fi
    # 4. 设备存在但没有挂载 → 主动挂载
    if [ -n "${DEV}" ] && [ -b "${DEV}" ]; then
        log "检测到 ${NAME} 设备但没有挂载: ${DEV}"
        mkdir -p "${NORMAL}"
        if mount "${DEV}" "${NORMAL}" 2>/dev/null; then
            log "${NAME} 自动挂载成功 → ${NORMAL}"
        else
            log "${NAME} 自动挂载失败"
        fi
    else
        log "未发现可用的 ${NAME} 设备"
    fi
}
# 双盘入口
mount_sd_fix()
{
    log "===== 开始检测磁盘挂载状态 ====="
    # 等待设备出现
    log "等待USB/SD磁盘设备出现（最长 ${DISK_WAIT_SEC} 秒）..."
    i=0
    FOUND=0
    while [ "${i}" -lt "${DISK_WAIT_SEC}" ]; do
        if ls /dev/sd[a-z]* >/dev/null 2>&1; then
            log "检测到块设备，额外等待3秒让系统完成识别..."
            sleep 3
            FOUND=1
            break
        fi
        if mount 2>/dev/null | grep -qE ' /tmp/mnt/SD|/tmp/mnt/SF'; then
            log "检测到SD/SF相关挂载点"
            FOUND=1
            break
        fi
        sleep 1
        i=$((i + 1))
    done
    if [ "${FOUND}" -eq 0 ]; then
        log "等待超时，未发现任何USB/SD块设备"
    fi
    # 识别设备
    discover_devices
    # 先清理所有可能的残留目录
    clean_stale_dir "${SD_MOUNT}"
    clean_stale_dir "${SF_MOUNT}"
    for n in 1 2 3 4 5; do
        clean_stale_dir "/tmp/mnt/SD(${n})"
        clean_stale_dir "/tmp/mnt/SF(${n})"
    done
    # 修复
    mount_fix_one "SD" "${SD_DEV}" "${SD_MOUNT}"
    mount_fix_one "SF" "${SF_DEV}" "${SF_MOUNT}"
    log "===== 磁盘检测完成 ====="
}
# ================= SSH公钥注入 =================
install_ssh_key()
{
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}" 2>/dev/null
    touch "${AUTH_FILE}"
    chmod 600 "${AUTH_FILE}" 2>/dev/null
    if [ -n "${SSH_KEY}" ] && [ "${SSH_KEY}" != "替换为你的完整SSH公钥" ]; then
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
        log "rclone_webdav.sh 将在 120 秒后后台启动"
        (
            sleep 120
            /bin/sh /jffs/scripts/rclone_webdav.sh >/dev/null 2>&1
        ) &
    else
        log "未找到 /jffs/scripts/rclone_webdav.sh"
    fi
}
# ================= 防火墙端口放行 =================
allow_port()
{
    PORT="$1"
    if ! iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null; then
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
        log "防火墙放行TCP端口 ${PORT} (IPv4)"
    else
        log "端口 ${PORT} (IPv4) 已放行"
    fi
    if command -v ip6tables >/dev/null 2>&1; then
        if ! ip6tables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null; then
            ip6tables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
            log "防火墙放行TCP端口 ${PORT} (IPv6)"
        fi
    fi
}
# ================= 防火墙持久化 =================
ensure_firewall_persist()
{
    FW_START="/jffs/scripts/firewall-start"
    mkdir -p /jffs/scripts
    if [ ! -f "${FW_START}" ]; then
        cat > "${FW_START}" <<'FWEOF'
#!/bin/sh
# Merlin firewall-start
FWEOF
        chmod +x "${FW_START}"
        log "创建 firewall-start"
    fi
    sed -i '/# >>> SSH_helper BEGIN >>>/,/# <<< SSH_helper END <<</d' "${FW_START}" 2>/dev/null
    cat >> "${FW_START}" <<FWEOF
# >>> SSH_helper BEGIN >>>
PORTS="${FW_PORTS}"
for port in \$PORTS
do
    iptables -C INPUT -p tcp --dport \$port -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport \$port -j ACCEPT
    if [ -x /usr/sbin/ip6tables ]; then
        /usr/sbin/ip6tables -C INPUT -p tcp --dport \$port -j ACCEPT 2>/dev/null || \
        /usr/sbin/ip6tables -I INPUT -p tcp --dport \$port -j ACCEPT
    fi
done
# <<< SSH_helper END <<<
FWEOF
    chmod +x "${FW_START}"
    log "firewall-start SSH_helper规则已更新"
}
# ================= 主入口 =================
log "================================================"
log "SSH_helper V12 启动"
log "运行路径 ${SCRIPT_DIR}"
log "日志文件 ${LOG_FILE}"
log "================================================"
# 1. 双磁盘修复
mount_sd_fix
# 2. SSH公钥
install_ssh_key
# 3. NVRAM
set_nvram
# 4. rclone
start_rclone
# 5. 运行时防火墙
for port in ${FW_PORTS}
do
    allow_port "${port}"
done
# 6. 防火墙持久化
ensure_firewall_persist
log "================================================"
log "SSH_helper V12 执行完成"
log "================================================"
exit 0
