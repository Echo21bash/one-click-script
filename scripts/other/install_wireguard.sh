#!/bin/bash

wireguard_install(){
	if [[ ${os_release} < '7' ]];then
		error_log "wireguard只支持Centos7"
		exit 1
	fi
	if [[ `modprobe wireguard` ]];then
		echo wireguard >/etc/modules-load.d/wireguard-modules.conf
	else
		error_log "缺少wireguard内核模块，请先升级高版本内核"
		exit
	fi
	system_optimize_yum
	cat > /etc/yum.repos.d/wireguard.repo <<-EOF
	[copr:copr.fedorainfracloud.org:jdoss:wireguard]
	name=Copr repo for wireguard owned by jdoss
	baseurl=https://download.copr.fedorainfracloud.org/results/jdoss/wireguard/epel-7-$basearch/
	type=rpm-md
	skip_if_unavailable=True
	gpgcheck=1
	gpgkey=https://download.copr.fedorainfracloud.org/results/jdoss/wireguard/pubkey.gpg
	repo_gpgcheck=0
	enabled=1
	enabled_metadata=1
	EOF
	yum install -y dkms iptables-services wireguard-dkms wireguard-tools
	if [[ $? = '0' ]];then
		success_log "wireguard安装成功"
	else
		error_log "wireguard安装失败"
		exit 1
	fi
}

wireguard_config(){
	mkdir /etc/wireguard
	cd /etc/wireguard
	###生成私钥和公钥
	wg genkey | tee server_private_key | wg pubkey > server_public_key
	wg genkey | tee client_private_key | wg pubkey > client_public_key
	s1=$(cat server_private_key)
	s2=$(cat server_public_key)
	c1=$(cat client_private_key)
	c2=$(cat client_public_key)
	get_public_ip
	get_net_name
	###配置文件
	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	PrivateKey = $s1
	Address = 10.0.0.1/24 
	PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${net_name} -j MASQUERADE
	PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${net_name} -j MASQUERADE
	ListenPort = 10111
	DNS = 8.8.8.8
	MTU = 1420

	[Peer]
	PublicKey = $c2
	AllowedIPs = 10.0.0.2/32
	EOF
	cat > /etc/wireguard/client.conf <<-EOF
	[Interface]
	PrivateKey = $c1
	Address = 10.0.0.2/24 
	DNS = 8.8.8.8
	MTU = 1420

	[Peer]
	PublicKey = $s2
	Endpoint = $public_ip:10111
	AllowedIPs = 0.0.0.0/0, ::0/0
	PersistentKeepalive = 25
	EOF

	ip_forward=$(cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1')
	if [[ -z ${ip_forward} ]];then
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
		sysctl -p > /dev/null
	fi
	systemctl start wg-quick@wg0
	if [[ -n $(ip a | grep -Eo '^wg0') ]];then
		success_log "wireguard启动成功，请下载/etc/wireguard/client.conf客户端配置文件"
	else
		error_log "wireguard启动失败"
	fi
}

wireguard_install_ctl(){

	wireguard_install
	wireguard_config
	service_control wg-quick@wg0
}


