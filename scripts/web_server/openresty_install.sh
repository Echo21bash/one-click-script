#!/bin/bash

openresty_env_load(){
	tmp_dir=/usr/local/src/openresty_tmp
	soft_name=openresty
	program_version=('1.15' '1.16' '1.17' '1.18' '1.19' '1.20' '1.21')
	url="https://repo.huaweicloud.com/openresty"
	select_version
	install_dir_set
	online_version
}

openresty_down(){

	online_down_file "${url}/v${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz"
	unpacking_file ${tmp_dir}/${soft_name}-${detail_version_number}.tar.gz ${tmp_dir}

}

dependent_install(){

	#安装编译工具及库文件
	diy_echo "正在安装编译工具及库文件..." "${info}"
	yum -y install make zlib zlib-devel gcc-c++ libtool  openssl openssl-devel pcre pcre-devel patch
	if [ $? = "0" ];then
		diy_echo "编译工具及库文件安装成功." "${info}"
	else
		diy_echo "编译工具及库文件安装失败请检查!!!" "${red}" "${error}" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

openresty_compile(){
	home_dir=${install_dir}/openresty
	mkdir -p ${home_dir}
	cd ${tar_dir}
	configure_arg="--prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module"

	./configure ${configure_arg}
	make && make install
	if [ $? = "0" ];then
		chown -R nginx.nginx ${home_dir}
		diy_echo "openresty安装成功." "${info} "
	else
		diy_echo "openresty安装失败!!!" "${red}" "${error}"
		exit 1
	fi

}

openresty_config(){
	conf_dir=${home_dir}/conf
	add_log_cut ${tmp_dir}/log_cut_openresty ${home_dir}/logs/*.log
	\cp ${tmp_dir}/log_cut_openresty /etc/logrotate.d
}

add_openresty_service(){

	Type="forking"
	ExecStart="${home_dir}/nginx/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/nginx/sbin/nginx -s reload"
	ExecStop="${home_dir}/nginx/sbin/nginx -s stop"
	add_daemon_file ${home_dir}/init
	add_system_service openresty ${home_dir}/init
}

openresty_install_ctl(){
	openresty_env_load
	install_dir_set
	openresty_down
	dependent_install
	openresty_compile
	openresty_config
	add_openresty_service
	
}