#!/bin/bash

go_env_load(){
	tmp_dir=/usr/local/src/go_tmp
	soft_name=go
	program_version=('1.13' '1.14' '1.15' '1.16' '1.17' '1.18' '1.19')
	url="http://mirrors.aliyun.com/golang/"
	select_version
	install_dir_set
	online_version
	down_url="${url}go${detail_version_number}.linux-amd64.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/go${detail_version_number}.linux-amd64.tar.gz ${tmp_dir}

}

go_install(){

	home_dir=${install_dir}/go
	mkdir -p ${home_dir}
	cp -rp ${tar_dir}/* ${home_dir}
	add_sys_env "PATH=${home_dir}/bin:\$PATH"

	go version
	if [ $? = 0 ];then
		info_log "go环境搭建成功."
	else
		error_log "go环境搭建失败."
		exit 1
	fi
}

go_install_ctl(){
	go_env_load
	go_install
	
}