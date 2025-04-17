#!/bin/bash

tengine_env_load(){
	tmp_dir=/usr/local/src/tengine_tmp
	soft_name=tengine
	program_version=(3)
	url="https://github.com/alibaba/tengine/"
	select_version
	install_dir_set
	online_version
}

tengine_down(){

	online_down_file "${url}/archive/refs/tags/${detail_version_number}.tar.gz"
	unpacking_file ${tmp_dir}/${detail_version_number}.tar.gz ${tmp_dir}

}

dependent_install(){

	#安装编译工具及库文件
	diy_echo "正在安装编译工具及库文件..." "${info}"
	yum -y install make zlib zlib-devel gcc-c++ libtool openssl openssl-devel pcre pcre-devel
	if [ $? = "0" ];then
		diy_echo "编译工具及库文件安装成功." "${info}"
	else
		diy_echo "编译工具及库文件安装失败请检查!!!" "${red}" "${error}" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

tengine_compile(){
	home_dir=${install_dir}/tengine
	mkdir -p ${home_dir}
	cd ${tar_dir}
	configure_arg="--prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module"

	./configure ${configure_arg}
	make && make install
	if [ $? = "0" ];then
		chown -R nginx.nginx ${home_dir}
		diy_echo "tengine安装成功." "${info}"
	else
		diy_echo "tengine安装失败!!!" "${red}" "${error}"
		exit 1
	fi

}

tengine_config(){
	conf_dir=${home_dir}/conf
	add_log_cut ${tmp_dir}/log_cut_tengine ${home_dir}/logs/*.log
	\cp ${tmp_dir}/log_cut_tengine /etc/logrotate.d
}

add_tengine_service(){

	Type="forking"
	ExecStart="${home_dir}/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/sbin/nginx -s reload"
	ExecStop="${home_dir}/sbin/nginx -s stop"
	add_daemon_file ${home_dir}/init
	add_system_service tengine ${home_dir}/init
}

tengine_install_ctl(){
	tengine_env_load
	tengine_down
	dependent_install
	tengine_compile
	tengine_config
	add_tengine_service
	
}