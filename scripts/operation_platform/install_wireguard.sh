#!/bin/bash

wireguard_env_check(){
	if [[ ${os_release} < '7' ]];then
		error_log "wireguard支持Centos7+"
		exit 1
	fi
	modprobe wireguard
	if [[ $? = 0 ]];then
		echo wireguard >/etc/modules-load.d/wireguard-modules.conf
	else
		error_log "缺少wireguard内核模块，请先升级最新内核"
		update_kernel
	fi
}

wireguard_env_load(){

	tmp_dir=/usr/local/src/wireguard_tmp
	mkdir -p ${tmp_dir}
	program_version=(0.3)
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
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

wireguard_install(){
	
	home_dir=${install_dir}/wireguard-ui
	mkdir -p ${home_dir}
	#安装wireguard界面
	\cp ${tmp_dir}/wireguard-ui ${home_dir}

	if [[ ! -f /etc/yum.repos.d/epel.repo ]];then
		cp ${workdir}/config/public/epel-7.repo /etc/yum.repos.d/epel.repo
	fi
	
	if [[ ! -f /etc/yum.repos.d/wireguard.repo ]];then
		cp ${workdir}/config/wireguard/wireguard.repo /etc/yum.repos.d/wireguard.repo
	fi
	#安装wireguard组件
	yum install -y dkms wireguard-dkms wireguard-tools
	if [[ $? = '0' ]];then
		success_log "wireguard安装成功"
	else
		error_log "wireguard安装失败"
		exit 1
	fi
}

wireguard_config(){
	get_ip
	ip_forward=$(cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1')
	if [[ -z ${ip_forward} ]];then
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
		sysctl -p > /dev/null
	fi
	\cp ${workdir}/config/wireguard/wg-reload.service /etc/systemd/system
	\cp ${workdir}/config/wireguard/wg-reload.path /etc/systemd/system
	service_control wg-reload.service enable
	service_control wg-reload.path enable
	service_control wg-quick@wg0 enable
	service_control wg-reload.service restart
	service_control wg-reload.path restart
	service_control wg-quick@wg0 restart
}

add_wireguard_ui_service(){
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/wireguard-ui"
	add_daemon_file	${home_dir}/wg-ui.service
	add_system_service wg-ui ${home_dir}/wg-ui.service
	service_control wg-ui enable
	service_control wg-ui start

}

wireguard_readme(){
	info_log "=====wireguard相关组件已经安装完成====="
	info_log "wireguard-ui页面地址http://${local_ip}:5000 用户名密码均为admin"
	info_log "wireguard-ui用户名密码均为admin"
	info_log "服务启停命令如下"
	service_control wg-ui usage
	service_control wg-quick@wg0 usage
}

wireguard_install_ctl(){
	wireguard_env_check
	wireguard_env_load
	wireguard_ui_down
	wireguard_install
	wireguard_config
	add_wireguard_ui_service
	wireguard_readme
}
