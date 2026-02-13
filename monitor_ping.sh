#!/bin/sh
LOG=/jffs/scripts/guangmao_ping.log
while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  if ping -c 1 -W 2 192.168.1.1 >/dev/null 2>&1; then
    echo "$TIMESTAMP - 正常" >> $LOG
  else
    echo "$TIMESTAMP - 超时 (可能光猫重启)" >> $LOG
  fi
  sleep 5
done
