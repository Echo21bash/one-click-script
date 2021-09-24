#!/bin/bash

filebeat_env_load(){
	tmp_dir=/usr/local/src/filebeat_tmp
	soft_name=filebeat
	program_version=('5' '6' '7')
	url='https://mirrors.huaweicloud.com/filebeat'
	select_version
	install_dir_set
	online_version	
}

filebeat_down(){
	if [[ ${os_bit} = '64' ]];then
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz"
		online_down_file
		unpacking_file ${tmp_dir}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz ${tmp_dir}
	else
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86.tar.gz"
		online_down_file
		unpacking_file ${tmp_dir}/${soft_name}-${detail_version_number}-linux-x86.tar.gz ${tmp_dir}
	fi

}

filebeat_install_set(){
	output_option "选择安装模式" "单机 批量" "deploy_mode"
	if [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/elk/filebeat.conf
		. ${workdir}/config/elk/filebeat.conf
	fi
}


filebeat_install(){
	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/filebeat
		mkdir -p ${install_dir}/filebeat/inputs.d
		\cp -rp ${tar_dir}/* ${home_dir}
		filebeat_conf
		add_filebeat_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
		home_dir=${install_dir}/filebeat
		filebeat_conf
		add_filebeat_service
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
			mkdir -p ${install_dir}/filebeat/inputs.d
			"
			info_log "正在向节点${now_host}分发filebeat安装程序和配置文件..."
			scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/filebeat
			scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/filebeat.service ${host_ip[$k]}:${install_dir}/filebeat
				
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
			\cp ${install_dir}/filebeat/filebeat.service /etc/systemd/system/filebeat.service
			systemctl daemon-reload
			"
			((k++))
		done
	fi
}

filebeat_conf(){
	conf_dir=${home_dir}/config
}

add_filebeat_service(){
	WorkingDirectory=${home_dir}
	ExecStart="${home_dir}/filebeat"
	if [[ ${deploy_mode} = '1' ]];then
		conf_system_service ${home_dir}/filebeat.service
		add_system_service filebeat ${home_dir}/filebeat.
	else
		conf_system_service ${tmp_dir}/filebeat.service
	fi
}

filebeat_install_ctl(){
	filebeat_env_load
	filebeat_install_set
	filebeat_down
	filebeat_install
	
}
