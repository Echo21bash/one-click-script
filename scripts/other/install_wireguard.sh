#!/bin/bash

wireguard_install(){
	if [[ ${os_release} < '7' ]];then
		echo -e "${error} wireguard只支持Centos7"
		exit 1
	fi

	system_optimize_yum
	cat > /etc/yum.repos.d/wireguard.repo <<-EOF
	[jdoss-wireguard]
	name=Copr repo for wireguard owned by jdoss
	baseurl=https://copr-be.cloud.fedoraproject.org/results/jdoss/wireguard/epel-7-$basearch/
	type=rpm-md
	skip_if_unavailable=True
	gpgcheck=1
	gpgkey=https://copr-be.cloud.fedoraproject.org/results/jdoss/wireguard/pubkey.gpg
	repo_gpgcheck=0
	enabled=1
	enabled_metadata=1
	EOF
	yum install -y dkms gcc-c++ gcc-gfortran glibc-headers glibc-devel libquadmath-devel libtool systemtap systemtap-devel iptables-services wireguard-dkms wireguard-tools
	if [[ $? = '0' ]];then
		echo -e "${info} wireguard安装成功"
	else
		echo -e "${error} wireguard安装失败"
		exit 2
	fi
}

wireguard_config(){
	mkdir /etc/wireguard
	cd /etc/wireguard
	wg genkey | tee sprivatekey | wg pubkey > spublickey
	wg genkey | tee cprivatekey | wg pubkey > cpublickey
	s1=$(cat sprivatekey)
	s2=$(cat spublickey)
	c1=$(cat cprivatekey)
	c2=$(cat cpublickey)
	get_public_ip
	get_net_name
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
		sysctl.conf -p > /dev/null
	fi
	systemctl start wg-quick@wg0
	if [[ -n $(ip a | grep -Eo '^wg0') ]];then
		echo -e "${info} wireguard启动成功，请下载/etc/wireguard/client.conf客户端配置文件"
	else
		echo -e "${info} wireguard启动失败"
	fi
}


wireguard_install
wireguard_config
service_control wg-quick@wg0

