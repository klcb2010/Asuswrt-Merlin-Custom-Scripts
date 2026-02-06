#!/bin/sh
# IPv6 Watchdog v6.78 - 去掉内部时间判断 + 全由 cron 控制 + 连续失败计数器
SCRIPT_VERSION="6.78"

LOG_DIR="/jffs/scripts"
PID_FILE="/var/run/ipv6_watchdog.pid"
PUSHPLUS_TOKEN="39ac79848955463abaccb22fa288134"
PUSHPLUS_URL="http://www.pushplus.plus/send"
IP_FILE="/jffs/scripts/last_ipv6"
MAX_RETRY=6
RETRY_INTERVAL=20
DDNS_HTTPS="https://.asuscomm.com:8443"
FAIL_COUNT_FILE="/tmp/ipv6_external_fail_count.txt"

mkdir -p "$LOG_DIR"

# PID 防多开
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  fi
  rm -f "$PID_FILE"
fi
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

log() {
  local LOG_FILE="$LOG_DIR/ipv6_watchdog_$(date +%Y-%m-%d).log"
  echo "[$(date '+%Y-%m-%d %H:%M:%S') v$SCRIPT_VERSION] $1" >> "$LOG_FILE" 2>/dev/null
}

pushplus_notify() {
  local content="$1"
  curl -s -X POST "$PUSHPLUS_URL" \
    -d "token=$PUSHPLUS_TOKEN" \
    -d "title=路由器 DDNS 异常" \
    -d "content=$content" \
    -d "template=html" >/dev/null 2>&1 && log "推送成功" || log "推送失败"
}

cleanup_old_logs() {
  TODAY_FILE="ipv6_watchdog_$(date +%Y-%m-%d).log"
  for old in "$LOG_DIR"/ipv6_watchdog_*.log; do
    [ -f "$old" ] && [ "$(basename "$old")" != "$TODAY_FILE" ] && rm -f "$old"
  done
}
cleanup_old_logs

CUR_IP=$(ip -6 addr show dev eth0 scope global 2>/dev/null | awk '/inet6 / {print $2}' | cut -d/ -f1 | head -n1)
LAST_IP=$(cat "$IP_FILE" 2>/dev/null)
ddns_status=$(nvram get ddns_status 2>/dev/null | tr -d ' \t\r\n')

ping_ok=1
ping -c 3 www.baidu.com >/dev/null 2>&1 || ping_ok=0

https_internal_ok=1
TEST_INTERNAL="https://[$CUR_IP]:8443"
curl -s -I -k --connect-timeout 15 --max-time 30 "$TEST_INTERNAL" >/dev/null 2>&1 || https_internal_ok=0

https_external_ok=1
curl -s -I -k --connect-timeout 15 --max-time 30 "$DDNS_HTTPS" >/dev/null 2>&1 || https_external_ok=0

change_triggered=0
if [ "$CUR_IP" != "$LAST_IP" ] && [ -n "$LAST_IP" ]; then change_triggered=1; fi

# 连续失败计数（只针对 external HTTPS 失败）
fail_count=0
if [ $https_external_ok -eq 0 ]; then
  if [ -f "$FAIL_COUNT_FILE" ]; then
    fail_count=$(cat "$FAIL_COUNT_FILE")
  fi
  fail_count=$((fail_count + 1))
  echo $fail_count > "$FAIL_COUNT_FILE"
else
  rm -f "$FAIL_COUNT_FILE"
fi

if [ "$ddns_status" != "1" ] || [ $change_triggered -eq 1 ] || [ $ping_ok -eq 0 ] || [ $https_internal_ok -eq 0 ] || [ $https_external_ok -eq 0 ]; then
  log "异常触发: status=$ddns_status, IPv6变化=$([ $change_triggered -eq 1 ] && echo 是 || echo 否), ping=$([ $ping_ok -eq 1 ] && echo 通 || echo 失败), internal=$([ $https_internal_ok -eq 1 ] && echo 通 || echo 失败), external=$([ $https_external_ok -eq 1 ] && echo 通 || echo 失败), fail_count=$fail_count"

  log "自动重启 httpd + letsencrypt"
  service restart_httpd
  service restart_letsencrypt
  sleep 15

  # 重测 external HTTPS
  https_external_ok_after=1
  curl -s -I -k --connect-timeout 15 --max-time 30 "$DDNS_HTTPS" >/dev/null 2>&1 || https_external_ok_after=0

  if [ $https_external_ok_after -eq 0 ]; then
    log "修复后 external HTTPS 仍失败 → 重启 DDNS"
    service restart_ddns

    success=""
    i=1
    while [ $i -le $MAX_RETRY ]; do
      sleep "$RETRY_INTERVAL"
      ddns_status=$(nvram get ddns_status 2>/dev/null | tr -d ' \t\r\n')
      log "DDNS重试 $i/$MAX_RETRY: $ddns_status"
      [ "$ddns_status" = "1" ] && success=1 && break
      i=$((i+1))
    done

    if [ -z "$success" ] && [ $fail_count -ge 3 ]; then
      content="连续失败（external HTTPS 超时 $fail_count 次）<br>$(date '+%Y-%m-%d %H:%M:%S')<br>已自动重启 httpd/letsencrypt/DDNS<br>重试 $MAX_RETRY 次后仍失败<br>status=$ddns_status<br>请手动检查"
      pushplus_notify "$content"
      log "连续失败 $fail_count 次，自愈失败，已推送"

      # WAN 重启已注释
      # log "必要时 → 自动重启 WAN"
      # service restart_wan
      # log "WAN 已重启"
    elif [ -n "$success" ]; then
      log "DDNS 自愈成功"
      rm -f "$FAIL_COUNT_FILE"
    fi
  else
    log "自动修复成功"
    rm -f "$FAIL_COUNT_FILE"
  fi
else
  log "状态正常"
  rm -f "$FAIL_COUNT_FILE"
fi

[ -n "$CUR_IP" ] && echo "$CUR_IP" > "$IP_FILE"
