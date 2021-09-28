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
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/elk/filebeat-single.conf
		. ${workdir}/config/elk/filebeat-single.conf
	fi
	if [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/elk/filebeat-batch.conf
		. ${workdir}/config/elk/filebeat-batch.conf
	fi
}


filebeat_install(){
	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/filebeat
		mkdir -p ${install_dir}/filebeat/input.d
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
			mkdir -p ${install_dir}/filebeat/input.d
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
	if [[ ${deploy_mode} = '1' ]];then
		if [[ ! -f ${home_dir}/filebeat.yml.bak ]];then
			cp ${home_dir}/filebeat.yml ${home_dir}/filebeat.yml.bak
		fi
		\cp ${workdir}/config/elk/filebeat-input.yml ${home_dir}/input.d
		\cp ${workdir}/config/elk/filebeat-main.yml ${home_dir}/filebeat.yml
		if [[ ${output_type} = 'elasticsearch' ]];then
			sed "/output.elasticsearch/{n;s/enabled: false/enabled: true/}" ${home_dir}/filebeat.yml
			sed "/output.console/{n;s/enabled: true/enabled: false/}" ${home_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:9200\"/${es_url}/" ${home_dir}/filebeat.yml
			if [[ -n ${es_name} && -n ${es_passwd} ]];then
				sed -i "s/#username:/username: ${es_name}/" ${home_dir}/filebeat.yml
				sed -i "s/#password:/#password: ${es_passwd}/" ${home_dir}/filebeat.yml
			fi
		fi
		if [[ ${output_type} = 'kafka' ]];then
			sed "/output.kafka/{n;s/enabled: false/enabled: true/}" ${home_dir}/filebeat.yml
			sed "/output.console/{n;s/enabled: true/enabled: false/}" ${home_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:9092\"/${kafka_url}/" ${home_dir}/filebeat.yml
		fi
		if [[ ${output_type} = 'redis' ]];then
			sed "/output.redis/{n;s/enabled: false/enabled: true/}" ${home_dir}/filebeat.yml
			sed "/output.console/{n;s/enabled: true/enabled: false/}" ${home_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:6379\"/${redis_url}/" ${home_dir}/filebeat.yml
			if [[ -n ${redis_passwd} ]];then
				sed -i "s/#password:/password: ${redis_passwd}/" ${home_dir}/filebeat.yml
			fi
		fi

	fi
	if [[ ${deploy_mode} = '2' ]];then
		mkdir -p ${tar_dir}/input.d
		if [[ ! -f ${tar_dir}/filebeat.yml.bak ]];then
			cp ${tar_dir}/filebeat.yml ${tar_dir}/filebeat.yml.bak
		fi
		\cp ${workdir}/config/elk/filebeat-input.yml ${tar_dir}/input.d
		\cp ${workdir}/config/elk/filebeat-main.yml ${tar_dir}/filebeat.yml
		if [[ ${output_type} = 'elasticsearch' ]];then
			sed -i "/output.elasticsearch/{n;s/enabled: false/enabled: true/}" ${tar_dir}/filebeat.yml
			sed -i "/output.console/{n;s/enabled: true/enabled: false/}" ${tar_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:9200\"/${es_url}/" ${tar_dir}/filebeat.yml
			if [[ -n ${es_name} && -n ${es_passwd} ]];then
				sed -i "s/#username:/username: ${es_name}/" ${tar_dir}/filebeat.yml
				sed -i "s/#password:/#password: ${es_passwd}/" ${tar_dir}/filebeat.yml
			fi
		fi
		if [[ ${output_type} = 'kafka' ]];then
			sed -i "/output.kafka/{n;s/enabled: false/enabled: true/}" ${tar_dir}/filebeat.yml
			sed -i "/output.console/{n;s/enabled: true/enabled: false/}" ${tar_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:9092\"/${kafka_url}/" ${tar_dir}/filebeat.yml
		fi
		if [[ ${output_type} = 'redis' ]];then
			sed -i "/output.redis/{n;s/enabled: false/enabled: true/}" ${tar_dir}/filebeat.yml
			sed -i "/output.console/{n;s/enabled: true/enabled: false/}" ${tar_dir}/filebeat.yml
			sed -i "s/\"192.168.1.1:6379\"/${redis_url}/" ${tar_dir}/filebeat.yml
			if [[ -n ${redis_passwd} ]];then
				sed -i "s/#password:/password: ${redis_passwd}/" ${tar_dir}/filebeat.yml
			fi
		fi

	fi
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
