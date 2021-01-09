#!/bin/bash

anylink_env_load(){

	tmp_dir=/tmp/anylink_tmp
	mkdir -p ${tmp_dir}
	program_version=(0)
	soft_name=anylink
	url='https://github.com/bjdgyc/anylink'
	select_version
	online_version
	install_dir_set
}

anylink_down(){
	
	down_url="${url}/releases/download/v${detail_version_number}/anylink-deploy-v${detail_version_number}.tar.gz"
	online_down_file
}

anylink_install(){
	home_dir=${install_dir}/anylink
	mkdir -p ${home_dir}
	unpacking_file ${tmp_dir}/anylink-deploy-v${detail_version_number}.tar.gz ${tmp_dir}
	cp -rp ${tar_dir}/* ${home_dir}
}

anylink_config(){

	ip_forward=$(cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1')
	if [[ -z ${ip_forward} ]];then
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
		sysctl -p > /dev/null
	fi
}

add_anylink_service(){
	WorkingDirectory="${home_dir}/anylink"
	ExecStart="${home_dir}/anylink"
	conf_system_service	${home_dir}/anylink.service
	add_system_service anylink ${home_dir}/anylink.service
	service_control anylink y

}


anylink_install_ctl(){
	anylink_env_check
	anylink_env_load
	anylink_down
	anylink_install
	anylink_config
	add_anylink_service
}


