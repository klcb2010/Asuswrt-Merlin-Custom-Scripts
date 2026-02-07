

260207  彻底放弃[ipv6](https://github.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/blob/ipv6/ipv6_watchdog.sh)
 频繁的前缀变化导致 某些设备比如 三星  苹果 设备失联   推荐ZeroTier 或Tailscale
开启华硕DDNS一定要光猫关闭防火墙  否则入站必然受阻   因为是动态ipv6 

 光猫改桥接导致IP变化更频繁  光猫网络设定中RA下方也需要勾选  让路由器更好的获取地址前缀

 重新注册设备卡百分之40 是因为没有运营商工单  呼叫网维处理

症状是内网访问DDNS正常 外网失败 
                                                                
适合梅林原版及改版、官改

运行 <pre><code class="language-html">chmod +x /jffs/scripts/ipv6_watchdog.sh
kill $(ps | grep ipv6_watchdog | grep -v grep | awk '{print $1}') 2>/dev/null
/jffs/scripts/ipv6_watchdog.sh &</code></pre>

脚本不是常驻   而是每次 cron 触发时运行一次，运行完就退出

查看日志<pre><code class="language-html">tail -f /jffs/scripts/ipv6_watchdog_$(date +%Y-%m-%d).log</code></pre>


1、定时任务前提条件
   　   安装 <pre><code class="language-html">/usr/sbin/curl -Os https://diversion.ch/amtm/amtm && sh amtm</code></pre>
   　   使用 SSH 　　 输入amtm　　  查看定时 　　重启路由测试  若提示卸载失败  则桥接移动网络热点安装  U盘若不能挂载  请更换U盘   不要期待有   脚本能实现

2、SS规则更新在路由软件中心管理界面先打开更新 再禁用定时 后面由定时任务接管


3、设定开机自动更新 定时任务 在jffs/scripts/post-mount里添加<pre><code class="language-html">#!/bin/sh
/jffs/scripts/set_crontab.sh &</code></pre>

4、下载 <pre><code class="language-html">mkdir -p /jffs/scripts/ && curl -o /jffs/scripts/Asuswrt-Merlin-Custom-Scripts.sh https://ghfast.top/https://raw.githubusercontent.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/main/Asuswrt-Merlin-Custom-Scripts.sh && chmod 777 /jffs/scripts/Asuswrt-Merlin-Custom-Scripts.sh</code></pre>

5、执行  /jffs/scripts/set_crontab.sh

6、规则更新前要SSH 输入替换规则  否则会提示未通过检验而导致更新失败 <pre><code class="language-html">sed -i 's|^URL_MAIN.*|URL_MAIN="https://raw.githubusercontent.com/qxzg/Actions/3.0/fancyss_rules"|' /koolshare/scripts/ss_rule_update.sh</code></pre>


7、开启华硕DDNS  从1002固件开启需要SSH手动开启 
脚本执行 在jffs/scripts/post-mount里添加  <pre> <code class="language-html">/jffs/scripts/set_territory.sh &</code></pre>


8 开启 webdav  用于向路由硬盘备份文档  同样在post-mount里调用   <pre> <code class="language-html">/jffs/scripts/rclone_webdav.sh &</code></pre>

前提 

刷 Asuswrt-Merlin 固件

插上 USB 已经分区的硬盘ext3和ntfs

开通外网访问：

网页后台开通 WAN 口 SSH（端口自定义默认22）

开通 asuscomm.com DDNS

开通 Let's Encrypt 免费证书（用于 HTTPS）

SSH 登录路由器，进入amtm 安装 Entware

通过amtm 安装 Entware 
<pre> <code class="language-html">reboot</code></pre>
<pre> <code class="language-html">opkg update</code></pre>
<pre> <code class="language-html">opkg install rclone</code></pre>
确认硬盘挂载路径 如 /tmp/mnt/SD/
<pre> <code class="language-html">ls /tmp/mnt/</code></pre>
<pre> <code class="language-html">df -h | grep mnt</code></pre>


创建独立自启脚本运行
<pre> <code class="language-html">/jffs/scripts/rclone_webdav.sh</code></pre>
重启后执行下列命令 看到 rclone 进程和日志
<pre> <code class="language-html">ps | grep [r]clone</code></pre>  

<pre> <code class="language-html">cat /tmp/rclone.log</code></pre> 


webdav地址是DDNS的地址:webdav端口

停止

<pre> <code class="language-html">killall rclone</code></pre>




9 monitor_ping.sh  简易光猫检查器  监测光猫状态  5秒一次 

启   动 nohup /jffs/scripts/monitor_ping.sh &
滚动日志 tail -f /jffs/scripts/guangmao_ping.log
