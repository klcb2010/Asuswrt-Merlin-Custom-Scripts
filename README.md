

查看进程   ps | grep -v grep | grep -E 'frpc|rclone'


260207  暂时放弃[ipv6](https://github.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/tree/ipv6)   

1、SS规则更新在路由软件中心管理界面先打开更新 再禁用定时 后面由定时任务接管


2、下载 <pre><code class="language-html">mkdir -p /jffs/scripts/ && curl -o /jffs/scripts/Asuswrt-Merlin-Custom-Scripts.sh https://ghfast.top/https://raw.githubusercontent.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/main/Asuswrt-Merlin-Custom-Scripts.sh && chmod 777 /jffs/scripts/Asuswrt-Merlin-Custom-Scripts.sh</code></pre>

3、执行  /jffs/scripts/set_crontab.sh

4、规则更新前要SSH 输入替换规则  否则会提示未通过检验而导致更新失败 <pre><code class="language-html">sed -i 's|^URL_MAIN.*|URL_MAIN="https://raw.githubusercontent.com/qxzg/Actions/3.0/fancyss_rules"|' /koolshare/scripts/ss_rule_update.sh</code></pre>

插上 USB 已经分区的硬盘ext3和ntfs

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

停止

<pre> <code class="language-html">killall rclone</code></pre>

7 monitor_ping.sh  简易光猫检查器  监测光猫状态  5秒一次 

启   动 nohup /jffs/scripts/monitor_ping.sh &

滚动日志 tail -f /jffs/scripts/guangmao_ping.log
