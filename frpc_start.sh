#!/bin/sh
# ============================================================
# 樱花 frpc 启动脚本 - 增强预检、跳过模式与人工干预
# ============================================================
# Token 配置  1=管理界面   2=远程文件 1+2共用密钥  ssh单独密钥

LOG="/tmp/frpc_start.log"
FRPC="/jffs/frpc/frpc"

# Token 配置
TOKEN_HTTP1="密钥:id"
TOKEN_HTTP2="密钥:id"
TOKEN_SSH="密钥:id"

# 颜色定义
R='\033[0;31m'
Y='\033[1;33m'
NC='\033[0m'

# 日志函数：超过 500 行自动清理
log() {
    [ $(wc -l < "$LOG" 2>/dev/null || echo 0) -gt 500 ] && echo "" > "$LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# --- 环境检查 (带手动退出提示) ---
if [ ! -f "$FRPC" ]; then
    echo -e "${R}[错误] 找不到核心文件: $FRPC${NC}"
    echo -e "${Y}请检查 SD 卡是否挂载或文件路径是否正确。${NC}"
    log "错误: 找不到文件 $FRPC，启动终止。"
    
    # 只有在终端交互模式下才等待输入
    if [ -t 0 ]; then
        echo -ne "${Y}按任意键退出脚本...${NC}"
        read -n 1
    fi
    exit 1
fi

start_instance() {
    TOKEN="$1"
    NAME="$2"
    [ -z "$TOKEN" ] && return

    # --- 核心跳过逻辑 ---
    if ps -w | grep "$TOKEN" | grep -v "grep" >/dev/null 2>&1; then
        log "$NAME 已经在运行中，跳过启动。"
        return 0
    fi

    # 只有没找到时，才会执行启动
    log "正在启动 $NAME "
    "$FRPC" -f "$TOKEN" >> "$LOG" 2>&1 &
}

# 依次检查并执行启动
start_instance "$TOKEN_HTTP1" "HTTP1"
start_instance "$TOKEN_HTTP2" "HTTP2"
start_instance "$TOKEN_SSH" "SSH"
