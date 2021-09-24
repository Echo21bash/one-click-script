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

filebeat_install(){
	mv ${tar_dir}/* ${home_dir}
	filebeat_conf
	add_filebeat_service
}

filebeat_conf(){
	get_ip
	conf_dir=${home_dir}/config
}

add_filebeat_service(){
	ExecStart="${home_dir}/filebeat"
	conf_system_service 
	add_system_service filebeat ${home_dir}/init
}

filebeat_install_ctl(){
	filebeat_env_load
	select_version
	filebeat_down
	filebeat_install
	
}
