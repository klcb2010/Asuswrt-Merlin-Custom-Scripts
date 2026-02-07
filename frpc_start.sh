llall frpc 2>/dev/null
echo "$(date '+%Y-%m-%d %H:%M:%S') 启动 frpc (id + id)" >> /jffs/frpc/frpc.log
nohup /jffs/frpc/frpc -f miyue:id,id >> /jffs/frpc/frpc.log 2>&1 &

