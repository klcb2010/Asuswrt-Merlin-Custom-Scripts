#!/bin/sh

# ================= 智能路径识别 =================
get_sd_path() {
    [ -d "/tmp/mnt/SD" ] && echo "/tmp/mnt/SD" && return
    df | grep "/tmp/mnt/" | grep -ivE 'defaults|rom|root|jffs' | awk '{print $NF}' | head -n 1
}

SD_PATH=$(get_sd_path)
SCRIPT_DIR="/jffs/scripts"
BACKUP_PREFIX="ax6000_scripts_backup"

# 颜色定义
G='\033[0;32m' ; Y='\033[1;33m' ; R='\033[0;31m' ; NC='\033[0m'

show_menu() {
    SD_PATH=$(get_sd_path)
    [ -z "$SD_PATH" ] && D_PATH="${R}未检测到外部存储!${NC}" || D_PATH="${G}$SD_PATH${NC}"
    echo -e "${Y}======================================"
    echo -e "      GT-AX6000 脚本备份管理工具"
    echo -e "      存储路径: $D_PATH"
    echo -e "======================================${NC}"
    echo " 1 立即备份 (仅限 .sh 脚本)"
    echo " 2 从该设备恢复最新备份"
    echo " 3 检查备份历史记录"
    echo " 4 手动删除指定备份"
    echo " 5 退出"
    echo -ne "${Y}请选择 [1-5]: ${NC}"
}

do_backup() {
    [ -z "$SD_PATH" ] && echo -e "${R}错误: 存储无效!${NC}" && return
    FILE_NAME="${BACKUP_PREFIX}$(date +%y%m%d%H%M).tar.gz"
    echo -e "${G}正在打包所有 .sh 脚本...${NC}"
    
    # 切换到目录精准打包所有 sh 文件，不带入杂质
    cd "$SCRIPT_DIR" || return
    tar -czf "${SD_PATH}/${FILE_NAME}" *.sh
    
    if [ $? -eq 0 ]; then
        echo -e "${G}[成功] 备份完成: $FILE_NAME${NC}"
        count=$(ls ${SD_PATH}/${BACKUP_PREFIX}*.tar.gz 2>/dev/null | wc -l)
        if [ "$count" -gt 7 ]; then
            ls -t ${SD_PATH}/${BACKUP_PREFIX}*.tar.gz | tail -n +8 | xargs rm -f
        fi
    else
        echo -e "${R}[失败] 备份出错${NC}"
    fi
}

do_restore() {
    [ -z "$SD_PATH" ] && echo -e "${R}错误: 存储无效!${NC}" && return
    LATEST=$(ls -t ${SD_PATH}/${BACKUP_PREFIX}*.tar.gz 2>/dev/null | head -n 1)
    [ -z "$LATEST" ] && echo -e "${R}未找到备份包。${NC}" && return

    echo -e "${Y}准备恢复: $(basename "$LATEST")${NC}"
    echo -ne "${R}确认恢复并重新赋权? (y/n): ${NC}"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # 解压到脚本目录
        tar -xzf "$LATEST" -C "$SCRIPT_DIR"
        
        # 核心：恢复后立即赋予所有脚本执行权限
        chmod +x ${SCRIPT_DIR}/*.sh
        echo -e "${G}权限赋值完成 (+x)${NC}"
        
        # 自动重载任务
        if [ -f "${SCRIPT_DIR}/init_tasks.sh" ]; then
            /bin/sh "${SCRIPT_DIR}/init_tasks.sh"
            echo -e "${G}[成功] 定时任务逻辑已同步!${NC}"
        fi
        echo -e "${G}[成功] 环境已完全恢复!${NC}"
    fi
}

do_delete() {
    [ -z "$SD_PATH" ] && echo -e "${R}错误: 存储无效!${NC}" && return
    files=$(ls -t ${SD_PATH}/${BACKUP_PREFIX}*.tar.gz 2>/dev/null)
    if [ -z "$files" ]; then echo -e "${R}未找到备份。${NC}"; return; fi

    echo -e "${Y}--- 现有备份列表 ---${NC}"
    i=1
    for f in $files; do
        echo "$i) $(basename $f)"
        eval "file_$i=\$f"
        i=$((i+1))
    done
    echo "q) 取消操作"
    echo -ne "${Y}请输入编号: ${NC}"
    read idx
    [ "$idx" = "q" ] && return
    
    target=$(eval echo \$file_$idx)
    if [ -n "$target" ] && [ -f "$target" ]; then
        rm -f "$target"
        echo -e "${G}已删除: $(basename "$target")${NC}"
    else
        echo -e "${R}无效编号!${NC}"
    fi
}

check_status() {
    echo -e "${Y}--- 存储盘状态 ---${NC}"
    [ -n "$SD_PATH" ] && df -h "$SD_PATH" || echo -e "${R}未发现盘符${NC}"
    
    echo -e "${Y}--- 备份记录 ---${NC}"
    history=$(ls -lh ${SD_PATH}/${BACKUP_PREFIX}*.tar.gz 2>/dev/null)
    if [ -z "$history" ]; then
        echo -e "${R}未找到任何备份记录。${NC}"
    else
        echo "$history" | tail -n 10
    fi
}

while true; do
    show_menu
    read choice
    case $choice in
        1) do_backup ;;
        2) do_restore ;;
        3) check_status ;;
        4) do_delete ;;
        5) exit 0 ;;
    esac
    echo -e "${Y}--------------------------------------${NC}"
done

