#!/bin/bash

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
	install_version filebeat
	install_selcet
	#filebeat_install_set
	install_dir_set
	download_unzip
	filebeat_install
	clear_install
}
