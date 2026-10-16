
<pre><code class="language-bash">start(){
detect_skipd
detect_httpdb
sleep 1
if [ -f "/koolshare/.soft_ver" ];then
dbus set softcenter_version=$(cat /koolshare/.soft_ver)
fi

    if [ -x /jffs/scripts/SSH_helper.sh ]; then
        (
            sleep 90
            /bin/sh /jffs/scripts/SSH_helper.sh >/tmp/ssh_helper_run.log 2>&1
        ) &
    fi
}</code></pre>





- SSH一键执行 <pre><code class="language-bash">curl -Lk "https://ghfast.top/raw.githubusercontent.com/klcb2010/Asuswrt-Merlin-Custom-Scripts/main/Asuswrt-Merlin-Custom-Scripts.sh" -o /tmp/setup.sh && chmod +x /tmp/setup.sh && /tmp/setup.sh; rm /tmp/setup.sh</code></pre>


SSH_helper.sh
放入/jffs/scripts/SSH_helper.sh，chmod +x 赋予执行权限，在 /jffs/.koolshare/init.d/V01softok.sh 中 set softcenter_version=$(cat /koolshare/.soft_ver) #	fi 代码块后追加启动调用代码   

     #	if [ -x /jffs/scripts/SSH_helper.sh ]; then
     #		/bin/sh /jffs/scripts/SSH_helper.sh >/tmp/ssh_helper_run.log 2>&1 &
     #	fi

  

## 光猫拨号时主要设置 IPV6设置

| 分类          | 子项                        | 设置值                          | 备注                     |
|---------------|-----------------------------|---------------------------------|--------------------------|
| 网络 - IPv4侧 | DNS来源                     | 网络连接                        |                          |
| 网络 - IPv4侧 | DHCP                        | √（启用）                       |                          |
| 网络 - IPv6侧 | DNS来源                     | 网络连接                        |                          |
| 网络 - IPv6侧 | 前缀来源                    | WAN Delegated                   |                          |
| 网络 - IPv6侧 | 地址信息是否通过DHCP获取    | ×（关闭）                       | SLAAC 方式               |
| 网络 - IPv6侧 | 其他信息是否通过DHCP获取    | √（启用）                       | 获取 DNS 等其他信息      |
| 网络 - IPv6侧 | RA使能                      | √（启用）                       |                          |
| 网络 - IPv6侧 | SLAAC 前缀使能              | √（启用）                       |       
| 网络 - IPv6侧 | 启用 DHCPv6 服务器          | √（启用）                       |                          |
| 网络 - IPv6侧 | RA 最大/最小间隔            | 默认值                          |                          |
| 网络 - IPv6侧 | 启用 IPv6 SEEION            | ×（关闭）                       |  
| QoS 设置      | 开启 QoS 模块               | ×（关闭）                       |                          |
| 安全 - 防火墙 | 防火墙等级                  | 低                              |                          |
| 安全 - 防火墙 | DoS 攻击保护                | ×（关闭）                       |                          |
| 管理          | 日志文件                    | 查看是否有错误日志              | 有错误日志请求换机          |

## 路由器主要设置

| 分类                | 子项                          | 设置值                                    | 备注                               |
|---------------------|-------------------------------|-------------------------------------------|------------------------------------|
| 外部网络 - 基本     | 联机类型                      | 静态 IP                                   |                                    |
| 外部网络 - 基本     | 启用 WAN                      | √（启用）                                 |                                    |
| 外部网络 - 基本     | 启动 NAT                      | √（启用）                                 |                                    |
| 外部网络 - 基本     | 启动 UPnP                     | √（启用）                                 |                                    |
| 外部网络 - 基本     | 启动 IGDv2                    | √（启用）                                 |                                    |
| 外部网络 - 基本     | Enable secure UPnP mode                | 是                                        |                                    |
| 外部网络 - IP 设置  | 互联网 IP 设置                | 从光猫获取的内网地址           |静态ip 如 192.168.1.7                       |
| 外部网络 - IP 设置  | 子网掩码                      | 255.255.255.0                               |     |
| 外部网络 - IP 设置  | 默认网关                      | 光猫 LAN IP 地址                          | 如 192.168.1.1                    |
| 外部网络 - DNS      | DNS 服务器                    | 233.5.5.5, 223.6.6.6                      | 可以不用         
| 外部网络 - DNS      | 转发到上游                    | 否                                   |                                    |
| 外部网络 - DNS      | 启用绑定保护                  | 否                                  |                                    |
| 外部网络 - DNS      | 启用 DNSSEC 支持              | 否                                        |                                    |
| 外部网络 - DNS      | 防止客户端自动 DoH            | 是                                        |                                    |
| IPv6 设置           | 联机类型                      | Passthrough                               | 路由器透传 IPv6               
| IPv6 设置           | Release prefix on exit        | 启用                                      | 断开时释放前缀                     |
| IPv6 DNS 设置       | 自动接上 DNS 服务器           | 启用                                      | 跟随上游 DNS                       |
| DDNS 设置           | Forced update interval        | 1                             | 强制更新间隔  1天                     |
| DDNS 设置           | IPv6 更新                     | 是                                        | 支持 IPv6 DDNS                     |

所有的 IPv6 TCP 连接必须根据路径自动调整大小 ssh命令 ip6tables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

NTP 服务器 cn.pool.ntp.org

查看进程    
<pre><code class="language-html">ps | grep -v grep | grep -E 'frpc|rclone'</code></pre>




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



