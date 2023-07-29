#!/bin/sh

result=0
mtd_part_name="Storage"
mtd_part_dev="/dev/mtdblock5"
mtd_part_size=15728640
dir_storage="/etc/storage"
slk="/tmp/.storage_locked"
tmp="/tmp/storage.tar"
tbz="${tmp}.bz2"
hsh="/tmp/hashes/storage_md5"

func_get_mtd()
{
	local mtd_part mtd_char mtd_idx mtd_hex
	mtd_part=`cat /proc/mtd | grep \"$mtd_part_name\"`
	mtd_char=`echo $mtd_part | cut -d':' -f1`
	mtd_hex=`echo $mtd_part | cut -d' ' -f2`
	mtd_idx=`echo $mtd_char | cut -c4-5`
	if [ -n "$mtd_idx" ] && [ $mtd_idx -ge 4 ] ; then
		mtd_part_dev="/dev/mtdblock${mtd_idx}"
		mtd_part_size=`echo $((0x$mtd_hex))`
	else
		logger -t "Storage" "Cannot find MTD partition: $mtd_part_name"
		exit 1
	fi
}

func_mdir()
{
	[ ! -d "$dir_storage" ] && mkdir -p -m 755 $dir_storage
}

func_stop_apps()
{
	killall -q rstats
	[ $? -eq 0 ] && sleep 1
}

func_start_apps()
{
	/sbin/rstats
}

func_load()
{
	local fsz

	bzcat $mtd_part_dev > $tmp 2>/dev/null
	fsz=`stat -c %s $tmp 2>/dev/null`
	if [ -n "$fsz" ] && [ $fsz -gt 0 ] ; then
		md5sum $tmp > $hsh
		tar xf $tmp -C $dir_storage 2>/dev/null
	else
		result=1
		rm -f $hsh
		logger -t "【mtd_storage.sh】" "MTD 分区中的无效存储数据: $mtd_part_dev"
	fi
	rm -f $tmp
	rm -f $slk
}

func_tarb()
{
	rm -f $tmp
	cd $dir_storage
	find * -print0 | xargs -0 touch -c -h -t 201001010000.00
	find * ! -type d -print0 | sort -z | xargs -0 tar -cf $tmp 2>/dev/null
	cd - >>/dev/null
	if [ ! -f "$tmp" ] ; then
		logger -t "【mtd_storage.sh】" "无法创建压缩包文件: $tmp"
		exit 1
	fi
}

func_save()
{
	local fsz

	logger -t "【mtd_storage.sh】" "保存存储文件到storage闪存 \"$mtd_part_dev\"请勿断电!"
	echo "Save storage files to MTD partition \"$mtd_part_dev\""
	rm -f $tbz
	md5sum -c -s $hsh 2>/dev/null
	if [ $? -eq 0 ] ; then
		echo "Storage hash is not changed, skip write to MTD partition. Exit."
		rm -f $tmp
		return 0
	fi
	md5sum $tmp > $hsh
	bzip2 -9 $tmp 2>/dev/null
	fsz=`stat -c %s $tbz 2>/dev/null`
	if [ -n "$fsz" ] && [ $fsz -ge 16 ] && [ $fsz -le $mtd_part_size ] ; then
		mtd_write write $tbz $mtd_part_name
		if [ $? -eq 0 ] ; then
			echo "Done."
			logger -t "【mtd_storage.sh】" "已完成."
		else
			result=1
			echo "Error! MTD write FAILED"
			logger -t "【mtd_storage.sh】" "写入MTD分区时出错: $mtd_part_dev"
		fi
	else
		result=1
		echo "Error! Invalid storage final data size: $fsz"
		logger -t "【mtd_storage.sh】" "存储最终数据大小无效: $fsz"
	fi
	rm -f $tmp
	rm -f $tbz
}

func_backup()
{
	rm -f $tbz
	bzip2 -9 $tmp 2>/dev/null
	if [ $? -ne 0 ] ; then
		result=1
		logger -t "【mtd_storage.sh】" "无法创建 BZ2 文件!"
	fi
	rm -f $tmp
}

func_restore()
{
	local fsz tmp_storage

	[ ! -f "$tbz" ] && exit 1

	fsz=`stat -c %s $tbz 2>/dev/null`
	if [ -z "$fsz" ] || [ $fsz -lt 16 ] || [ $fsz -gt $mtd_part_size ] ; then
		result=1
		rm -f $tbz
		logger -t "【mtd_storage.sh】" "BZ2 文件大小无效: $fsz"
		return 1
	fi

	tmp_storage="/tmp/storage"
	rm -rf $tmp_storage
	mkdir -p -m 755 $tmp_storage
	tar xjf $tbz -C $tmp_storage 2>/dev/null
	if [ $? -ne 0 ] ; then
		result=1
		rm -f $tbz
		rm -rf $tmp_storage
		logger -t "【mtd_storage.sh】" "无法提取 BZ2 文件: $tbz"
		return 1
	fi
	if [ ! -f "$tmp_storage/start_script.sh" ] ; then
		result=1
		rm -f $tbz
		rm -rf $tmp_storage
		logger -t "【mtd_storage.sh】" "BZ2 文件内容无效: $tbz"
		return 1
	fi

	func_stop_apps

	rm -f $slk
	rm -f $tbz
	rm -rf $dir_storage
	mkdir -p -m 755 $dir_storage
	cp -rf $tmp_storage /etc
	rm -rf $tmp_storage

	func_start_apps
}

func_erase()
{
	mtd_write erase $mtd_part_name
	if [ $? -eq 0 ] ; then
		rm -f $hsh
		rm -rf $dir_storage
		mkdir -p -m 755 $dir_storage
		touch "$slk"
	else
		result=1
	fi
}

func_reset()
{
	rm -f $slk
	rm -rf $dir_storage
	mkdir -p -m 755 $dir_storage
}

func_fill()
{
        
        
	dir_httpssl="$dir_storage/https"
	dir_dnsmasq="$dir_storage/dnsmasq"
	dir_ovpnsvr="$dir_storage/openvpn/server"
	dir_ovpncli="$dir_storage/openvpn/client"
	dir_sswan="$dir_storage/strongswan"
	dir_sswan_crt="$dir_sswan/ipsec.d"
	dir_inadyn="$dir_storage/inadyn"
	dir_crond="$dir_storage/cron/crontabs"
	dir_wlan="$dir_storage/wlan"
	dir_chnroute="$dir_storage/chinadns"
	#dir_gfwlist="$dir_storage/gfwlist"

	script_start="$dir_storage/start_script.sh"
	script_started="$dir_storage/started_script.sh"
	script_shutd="$dir_storage/shutdown_script.sh"
	script_postf="$dir_storage/post_iptables_script.sh"
	script_postw="$dir_storage/post_wan_script.sh"
	script_inets="$dir_storage/inet_state_script.sh"
	script_vpnsc="$dir_storage/vpns_client_script.sh"
	script_vpncs="$dir_storage/vpnc_server_script.sh"
	script_ezbtn="$dir_storage/ez_buttons_script.sh"
	script_gipv6="$dir_storage/getipv6.sh"
	script_ipv6="$dir_storage/ipv6.sh"

	user_hosts="$dir_dnsmasq/hosts"
	user_dnsmasq_conf="$dir_dnsmasq/dnsmasq.conf"
	user_dhcp_conf="$dir_dnsmasq/dhcp.conf"
	user_ovpnsvr_conf="$dir_ovpnsvr/server.conf"
	user_ovpncli_conf="$dir_ovpncli/client.conf"
	user_inadyn_conf="$dir_inadyn/inadyn.conf"
	user_sswan_conf="$dir_sswan/strongswan.conf"
	user_sswan_ipsec_conf="$dir_sswan/ipsec.conf"
	user_sswan_secrets="$dir_sswan/ipsec.secrets"
	
	if [ ! -d "/etc/storage/bin" ] ; then
mkdir -p /etc/storage/bin
fi

	chnroute_file="/etc_ro/chnroute.bz2"
	#gfwlist_conf_file="/etc_ro/gfwlist.bz2"

	# create crond dir
	[ ! -d "$dir_crond" ] && mkdir -p -m 730 "$dir_crond"

	# create https dir
	[ ! -d "$dir_httpssl" ] && mkdir -p -m 700 "$dir_httpssl"

	# create chnroute.txt
	if [ ! -d "$dir_chnroute" ] ; then
		if [ -f "$chnroute_file" ]; then
			mkdir -p "$dir_chnroute" && tar jxf "$chnroute_file" -C "$dir_chnroute"
		fi
	fi

	# create gfwlist
	#if [ ! -d "$dir_gfwlist" ] ; then
	#	if [ -f "$gfwlist_conf_file" ]; then	
	#		mkdir -p "$dir_gfwlist" && tar jxf "$gfwlist_conf_file" -C "$dir_gfwlist"
	#	fi
	#fi

	# create start script
	if [ ! -f "$script_start" ] ; then
		reset_ss.sh -a
	fi

	# create started script
	if [ ! -f "$script_started" ] ; then
		cat > "$script_started" <<'EOF'
#!/bin/sh

### Custom user script
### Called after router started and network is ready

### Example - load ipset modules
#modprobe ip_set
#modprobe ip_set_hash_ip
#modprobe ip_set_hash_net
#modprobe ip_set_bitmap_ip
#modprobe ip_set_list_set
#modprobe xt_set
echo 4096 131072  6291456 > /proc/sys/net/ipv4/tcp_rmem
echo 4194304 >/proc/sys/net/core/rmem_max
echo 212992 > /proc/sys/net/core/rmem_default

#drop caches
sync && echo 3 > /proc/sys/vm/drop_caches

# Roaming assistant for mt76xx WiFi
#iwpriv ra0 set KickStaRssiLow=-85
#iwpriv ra0 set AssocReqRssiThres=-80
#iwpriv rai0 set KickStaRssiLow=-85
#iwpriv rai0 set AssocReqRssiThres=-80

# Mount SATA disk
#mdev -s

#wing <HOST:443> <PASS>
#wing 192.168.1.9:1080
#ipset add gfwlist 8.8.4.4
#iOS设备访问慢？
#echo 0 > /proc/sys/net/ipv4/tcp_tw_recycle


#************微信推送*******************
#自建微信推送申请地址：https://mp.weixin.qq.com/debug/cgi-bin/sandbox?t=sandbox/login
#教程：https://opt.cn2qq.com/opt-file/测试号配置.pdf
#1.下方填写申请的appid=（= 中间必须要留有空格）例如=  wx9137fdf261df9f7d
#wx_appid= 
#2.下方填写申请的appsecret=（= 中间必须要留有空格）例如=  b2a0256470a6cf7e3f3a9e63c8197560
#wx_appsecret= 
#3.下方填写申请的微信号=（= 中间必须要留有空格）例如=  ok5hz6FNykEAX9X7VnKuFd7YCPqg
#wxsend_touser= 
#4.下方填写申请的模板ID=（= 中间必须要留有空格）例如=  pHc01IZWHyM3NOC-8vQ26XAB-mApPLrWVZI1A29iSj0
#wxsend_template_id= 
#*****以下功能推送脚本路径：/etc/storage/wxsendfile.sh **********
#1.下方填= 1启用WAN口IP变动推送 （= 中间必须要留有空格）例如= 1
#wxsend_notify_1= 1 
#2.下方填= 1启用设备接入推送（= 中间必须要留有空格）例如= 1
#wxsend_notify_2= 1
#3.下方填= 1启用设备上、下线推送（= 中间必须要留有空格）例如= 1
#wxsend_notify_3= 1
#4.下方填= 1启用自定义内容推送（= 中间必须要留有空格）例如= 1
#wxsend_notify_4= 1
#4.修改微信推送脚本的路径/etc/storage/wxsendfile.sh
#4.自定义教程：自建微信推送脚本ipv6进程守护循环检测https://www.right.com.cn/forum/thread-8282061-1-1.html
#5.下方填= 循环检测的时间，每隔多少秒检测一次 秒为单位（= 中间必须要留有空格）例如三分钟= 180
#wxsend_time= 60
#6.下方代码去掉前面的#,表示启用微信推送开机自启
#wx_send.sh start &
#************微信推送*******************


EOF
		chmod 755 "$script_started"
	fi

	# create shutdown script
	if [ ! -f "$script_shutd" ] ; then
		cat > "$script_shutd" <<EOF
#!/bin/sh

### Custom user script
### Called before router shutdown
### \$1 - action (0: reboot, 1: halt, 2: power-off)


EOF
		chmod 755 "$script_shutd"
	fi

	# create post-iptables script

	if [ ! -f "$script_postf" ] ; then
		cat > "$script_postf" <<EOF
#!/bin/sh

### Custom user script
### Called after internal iptables reconfig (firewall update)

#wing resume
### ipv6防火墙全关规则 以下把#去掉则关闭ip6防火墙 
#ip6tables -F
#ip6tables -X
#ip6tables -P INPUT ACCEPT
#ip6tables -P OUTPUT ACCEPT
#ip6tables -P FORWARD ACCEPT
### ipv6防火墙单独规则 开放3389远程桌面 其它端口按下方规则添加 以下把#去掉则生效
#ip6tables -I FORWARD -p tcp --dport 3389 -j ACCEPT
#ip6tables -I FORWARD -p tcp --dport 8829 -j ACCEPT
EOF
		chmod 755 "$script_postf"
	fi

# create gipv6 script

if [ ! -f "$script_gipv6" ] ; then
		cat > "$script_gipv6" <<EOF
#!/bin/sh
### Custom user script
### getipv6
#wing resume
hostipv6=\`ip -6 neighbor show | grep -i  \$1 | sed -n 's/.dev* \([0-9a-f:]\+\).*/\2/p' |  grep -v fe80:: |tail -n 1\`
echo \${hostipv6}
EOF
		chmod 755 "$script_gipv6"
fi

# create ipv6 script


if [ ! -f "$script_ipv6" ] ; then
		cat > "$script_ipv6" <<EOF
#!/bin/sh
### Custom user script
### showipv6
#wing resume
cat /tmp/static_ip.inf | grep -v  "^$" | awk -F "," ' { sh "/etc/storage/getipv6.sh " \$2 |getline result;if ( \$6 == 0 ) print \$1,result ","\$2","\$3","\$4","\$5","\$6} ' > /tmp/static_ipv6.inf
EOF
		chmod 755 "$script_ipv6"
fi


# create post-wan script

if [ ! -f "$script_postw" ] ; then
	cat > "$script_postw" <<EOF
#!/bin/sh

### Called after internal WAN up/down action
### \$1 - WAN action (up/down)
### \$2 - WAN interface name (e.g. eth3 or ppp0)
### \$3 - WAN IPv4 address



EOF

	chmod 755 "$script_postw"
fi

	# create inet-state script
	if [ ! -f "$script_inets" ] ; then
		cat > "$script_inets" <<EOF
#!/bin/sh

### Custom user script
### Called on Internet status changed
### \$1 - Internet status (0/1)
### \$2 - elapsed time (s) from previous state

logger -t "di" "Internet state: \$1, elapsed time: \$2s."

EOF
		chmod 755 "$script_inets"
	fi

	# create vpn server action script
	if [ ! -f "$script_vpnsc" ] ; then
		cat > "$script_vpnsc" <<EOF
#!/bin/sh

### Custom user script
### Called after remote peer connected/disconnected to internal VPN server
### \$1 - peer action (up/down)
### \$2 - peer interface name (e.g. ppp10)
### \$3 - peer local IP address
### \$4 - peer remote IP address
### \$5 - peer name

peer_if="\$2"
peer_ip="\$4"
peer_name="\$5"

### example: add static route to private LAN subnet behind a remote peer

func_ipup()
{
#  if [ "\$peer_name" == "dmitry" ] ; then
#    route add -net 192.168.5.0 netmask 255.255.255.0 dev \$peer_if
#  elif [ "\$peer_name" == "victoria" ] ; then
#    route add -net 192.168.8.0 netmask 255.255.255.0 dev \$peer_if
#  fi
   return 0
}

func_ipdown()
{
#  if [ "\$peer_name" == "dmitry" ] ; then
#    route del -net 192.168.5.0 netmask 255.255.255.0 dev \$peer_if
#  elif [ "\$peer_name" == "victoria" ] ; then
#    route del -net 192.168.8.0 netmask 255.255.255.0 dev \$peer_if
#  fi
   return 0
}

case "\$1" in
up)
  func_ipup
  ;;
down)
  func_ipdown
  ;;
esac

EOF
		chmod 755 "$script_vpnsc"
	fi

	# create vpn client action script
	if [ ! -f "$script_vpncs" ] ; then
		cat > "$script_vpncs" <<EOF
#!/bin/sh

### Custom user script
### Called after internal VPN client connected/disconnected to remote VPN server
### \$1        - action (up/down)
### \$IFNAME   - tunnel interface name (e.g. ppp5 or tun0)
### \$IPLOCAL  - tunnel local IP address
### \$IPREMOTE - tunnel remote IP address
### \$DNS1     - peer DNS1
### \$DNS2     - peer DNS2

# private LAN subnet behind a remote server (example)
peer_lan="192.168.9.0"
peer_msk="255.255.255.0"

### example: add static route to private LAN subnet behind a remote server

func_ipup()
{
#  route add -net \$peer_lan netmask \$peer_msk gw \$IPREMOTE dev \$IFNAME
   return 0
}

func_ipdown()
{
#  route del -net \$peer_lan netmask \$peer_msk gw \$IPREMOTE dev \$IFNAME
   return 0
}

logger -t vpnc-script "\$IFNAME \$1"

case "\$1" in
up)
  func_ipup
  ;;
down)
  func_ipdown
  ;;
esac

EOF
		chmod 755 "$script_vpncs"
	fi

	# create Ez-Buttons script
	if [ ! -f "$script_ezbtn" ] ; then
		cat > "$script_ezbtn" <<EOF
#!/bin/sh

### Custom user script
### Called on WPS or FN button pressed
### \$1 - button param

[ -x /opt/bin/on_wps.sh ] && /opt/bin/on_wps.sh \$1 &

EOF
		chmod 755 "$script_ezbtn"
	fi

	# create user dnsmasq.conf
	[ ! -d "$dir_dnsmasq" ] && mkdir -p -m 755 "$dir_dnsmasq"
	for i in dnsmasq.conf hosts ; do
		[ -f "$dir_storage/$i" ] && mv -n "$dir_storage/$i" "$dir_dnsmasq"
	done
	if [ ! -f "$user_dnsmasq_conf" ] ; then
		cat > "$user_dnsmasq_conf" <<EOF
# Custom user conf file for dnsmasq
# Please add needed params only!

### Web Proxy Automatic Discovery (WPAD)
dhcp-option=252,"\n"

### Set the limit on DHCP leases, the default is 150
#dhcp-lease-max=150

### Add local-only domains, queries are answered from hosts or DHCP only
#local=/router/localdomain/

### Examples:

### Enable built-in TFTP server
#enable-tftp

### Set the root directory for files available via TFTP.
#tftp-root=/opt/srv/tftp

### Make the TFTP server more secure
#tftp-secure

### Set the boot filename for netboot/PXE
#dhcp-boot=pxelinux.0

### Log for all queries
#log-queries

### Keep DHCP host name valid at any times
#dhcp-to-host

EOF
	if [ -f /usr/bin/vlmcsd ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
### vlmcsd related
srv-host=_vlmcs._tcp,my.router,1688,0,100

EOF
	fi

	if [ -f /usr/bin/wing ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
# Custom domains to gfwlist
#gfwlist=mit.edu
#gfwlist=openwrt.org,lede-project.org
#gfwlist=github.com,github.io,githubusercontent.com

EOF
	fi

	if [ -d $dir_gfwlist ]; then
		cat >> "$user_dnsmasq_conf" <<EOF
### gfwlist related (resolve by port 5353)
#min-cache-ttl=3600
#conf-dir=/etc/storage/gfwlist

EOF
	fi
		chmod 644 "$user_dnsmasq_conf"
	fi

	# create user dns servers
	if [ ! -f "$user_dhcp_conf" ] ; then
		cat > "$user_dhcp_conf" <<EOF
#6C:96:CF:E0:95:55,192.168.1.10,iMac

EOF
		chmod 644 "$user_dhcp_conf"
	fi

	# create user inadyn.conf"
	[ ! -d "$dir_inadyn" ] && mkdir -p -m 755 "$dir_inadyn"
	if [ ! -f "$user_inadyn_conf" ] ; then
		cat > "$user_inadyn_conf" <<EOF
# Custom user conf file for inadyn DDNS client
# Please add only new custom system!

### Example for twoDNS.de:

#system custom@http_srv_basic_auth
#  ssl
#  checkip-url checkip.two-dns.de /
#  server-name update.twodns.de
#  server-url /update\?hostname=
#  username account
#  password secret
#  alias example.dd-dns.de

EOF
		chmod 644 "$user_inadyn_conf"
	fi

	# create user hosts
	if [ ! -f "$user_hosts" ] ; then
		cat > "$user_hosts" <<EOF
# Custom user hosts file
# Example:
# 192.168.1.100		Boo

EOF
		chmod 644 "$user_hosts"
	fi

	# create user AP confs
	[ ! -d "$dir_wlan" ] && mkdir -p -m 755 "$dir_wlan"
	if [ ! -f "$dir_wlan/AP.dat" ] ; then
		cat > "$dir_wlan/AP.dat" <<EOF
# Custom user AP conf file

EOF
		chmod 644 "$dir_wlan/AP.dat"
	fi

	if [ ! -f "$dir_wlan/AP_5G.dat" ] ; then
		cat > "$dir_wlan/AP_5G.dat" <<EOF
# Custom user AP conf file

EOF
		chmod 644 "$dir_wlan/AP_5G.dat"
	fi

	# create openvpn files
	if [ -x /usr/sbin/openvpn ] ; then
		[ ! -d "$dir_ovpncli" ] && mkdir -p -m 700 "$dir_ovpncli"
		[ ! -d "$dir_ovpnsvr" ] && mkdir -p -m 700 "$dir_ovpnsvr"
		dir_ovpn="$dir_storage/openvpn"
		for i in ca.crt dh1024.pem server.crt server.key server.conf ta.key ; do
			[ -f "$dir_ovpn/$i" ] && mv -n "$dir_ovpn/$i" "$dir_ovpnsvr"
		done
		if [ ! -f "$user_ovpnsvr_conf" ] ; then
			cat > "$user_ovpnsvr_conf" <<EOF
# Custom user conf file for OpenVPN server
# Please add needed params only!

### Max clients limit
max-clients 10

### Internally route client-to-client traffic
client-to-client

### Allow clients with duplicate "Common Name"
;duplicate-cn

### Legacy LZO adaptive compression
;comp-lzo adaptive
;push "comp-lzo adaptive"

### Keepalive and timeout
keepalive 10 60

### Process priority level (0..19)
nice 3

### Syslog verbose level
verb 0
mute 10

EOF
			chmod 644 "$user_ovpnsvr_conf"
		fi

		if [ ! -f "$user_ovpncli_conf" ] ; then
			cat > "$user_ovpncli_conf" <<EOF
# Custom user conf file for OpenVPN client
# Please add needed params only!

### If your server certificates with the nsCertType field set to "server"
remote-cert-tls server

### Process priority level (0..19)
nice 0

### Syslog verbose level
verb 0
mute 10

EOF
			chmod 644 "$user_ovpncli_conf"
		fi
	fi

	# create strongswan files
	if [ -x /usr/sbin/ipsec ] ; then
		[ ! -d "$dir_sswan" ] && mkdir -p -m 700 "$dir_sswan"
		[ ! -d "$dir_sswan_crt" ] && mkdir -p -m 700 "$dir_sswan_crt"
		[ ! -d "$dir_sswan_crt/cacerts" ] && mkdir -p -m 700 "$dir_sswan_crt/cacerts"
		[ ! -d "$dir_sswan_crt/certs" ] && mkdir -p -m 700 "$dir_sswan_crt/certs"
		[ ! -d "$dir_sswan_crt/private" ] && mkdir -p -m 700 "$dir_sswan_crt/private"

		if [ ! -f "$user_sswan_conf" ] ; then
			cat > "$user_sswan_conf" <<EOF
### strongswan.conf - user strongswan configuration file

EOF
			chmod 644 "$user_sswan_conf"
		fi
		if [ ! -f "$user_sswan_ipsec_conf" ] ; then
			cat > "$user_sswan_ipsec_conf" <<EOF
### ipsec.conf - user strongswan IPsec configuration file

EOF
			chmod 644 "$user_sswan_ipsec_conf"
		fi
		if [ ! -f "$user_sswan_secrets" ] ; then
			cat > "$user_sswan_secrets" <<EOF
### ipsec.secrets - user strongswan IPsec secrets file

EOF
			chmod 644 "$user_sswan_secrets"
		fi
	fi
}

case "$1" in
load)
	func_get_mtd
	func_mdir
	func_load
	;;
save)
	[ -f "$slk" ] && exit 1
	func_get_mtd
	func_mdir
	func_tarb
	func_save
	;;
backup)
	func_mdir
	func_tarb
	func_backup
	;;
restore)
	func_get_mtd
	func_restore
	;;
erase)
	func_get_mtd
	func_erase
	;;
reset)
	func_stop_apps
	func_reset
	func_fill
	func_start_apps
	;;
fill)
	func_mdir
	func_fill
	;;
*)
	echo "Usage: $0 {load|save|backup|restore|erase|reset|fill}"
	exit 1
	;;
esac

exit $result
