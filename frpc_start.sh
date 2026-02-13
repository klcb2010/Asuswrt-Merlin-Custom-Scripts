#!/bin/sh

# --- 配置区 ---
LOG_FILE="/tmp/frpc_start.log"
LOCK_FILE="/tmp/frpc_start.lock"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 1. 脚本保活：如果脚本已在运行，则跳过
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        # 脚本正在执行动作，直接退出
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

# 2. 核心检测：检查 frpc 进程是否存在
if ! pidof frpc > /dev/null; then
    log "检测到 frpc 进程丢失，正在尝试重启..."
    
    # 彻底清理旧进程
    killall -9 frpc 2>/dev/null
    sleep 2
    
    # 执行启动（使用你的专属 Token 和端口参数）
    nohup /jffs/frpc/frpc -f macoz8xw2s8rxnlhnr2atezhisbh290m:25824112,25823996 >> "$LOG_FILE" 2>&1 &
    
    if [ $? -eq 0 ]; then
        log "frpc 启动指令已发送 (Token: macoz8...)。"
    fi
else
    # 进程正常，无需重复操作
    exit 0
fi

# 3. 释放锁文件
rm -f "$LOCK_FILE"
