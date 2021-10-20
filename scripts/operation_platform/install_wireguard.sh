#!/bin/bash
set -e

wireguard_env_check(){
	if [[ ${os_release} < '7' ]];then
		error_log "wireguard支持Centos7+"
		exit 1
	fi
	modprobe wireguard
	if [[ $? = 0 ]];then
		echo wireguard >/etc/modules-load.d/wireguard-modules.conf
	else
		error_log "缺少wireguard内核模块，请先升级高版本内核"
		update_kernel
	fi
}

wireguard_env_load(){

	tmp_dir=/usr/local/src/wireguard_tmp
	mkdir -p ${tmp_dir}
	program_version=(0)
	soft_name=wireguard-ui
	url='https://github.com/ngoduykhanh/wireguard-ui'
	select_version
	online_version
	install_dir_set
}

wireguard_ui_down(){
	if [[ ${os_bit} = '64' ]];then
		down_url="${url}/releases/download/v${detail_version_number}/wireguard-ui-v${detail_version_number}-linux-amd64.tar.gz"
	else
		down_url="${url}/releases/download/v${detail_version_number}/wireguard-ui-v${detail_version_number}-linux-386.tar.gz"
	fi
	online_down_file
}

wireguard_install(){

	if [[ ! -f /etc/yum.repos.d/epel.repo ]];then
		cp ${workdir}/config/public/epel-7.repo /etc/yum.repos.d/epel.repo
	fi
	
	if [[ ! -f /etc/yum.repos.d/wireguard.repo ]];then
		cp ${workdir}/config/wireguard/wireguard.repo /etc/yum.repos.d/wireguard.repo
	fi
	yum install -y dkms wireguard-dkms wireguard-tools
	if [[ $? = '0' ]];then
		success_log "wireguard安装成功"
	else
		error_log "wireguard安装失败"
		exit 1
	fi
}

wireguard_config(){

	ip_forward=$(cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1')
	if [[ -z ${ip_forward} ]];then
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
		sysctl -p > /dev/null
	fi
	systemctl start wg-quick@wg0
	if [[ -n $(ip a | grep -Eo 'wg0') ]];then
		success_log "wireguard启动成功，请下载/etc/wireguard/client.conf客户端配置文件"
	else
		error_log "wireguard启动失败"
		exit 1
	fi
	cp ${workdir}/config/wireguard/wg-reload.service /etc/systemd/system
	cp ${workdir}/config/wireguard/wg-reload.path /etc/systemd/system
	systemctl daemon-reload
	systemctl enable wg-reload.service wg-reload.path wg-quick@wg0
}

add_wireguard_ui_service(){
	WorkingDirectory="${home_dir}/wireguard-ui"
	ExecStart="${home_dir}/wireguard-ui"
	add_daemon_file	${home_dir}/wgui.service
	add_system_service wgui ${home_dir}/wgui.service
	service_control wgui start

}


wireguard_install_ctl(){
	wireguard_env_check
	wireguard_env_load
	wireguard_ui_down
	wireguard_install
	wireguard_config
	add_wireguard_ui_service
}


