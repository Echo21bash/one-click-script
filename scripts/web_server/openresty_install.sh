#!/bin/bash

openresty_env_load(){
	tmp_dir=/tmp/openresty_tmp
	soft_name=openresty
	program_version=(1.13 1.14 1.15)
	url="https://mirrors.huaweicloud.com/openresty"
	down_url='${url}/v${detail_version_number}/v${detail_version_number}.tar.gz'
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
	cd ${tar_dir}
	configure_arg="--prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module"

	./configure ${configure_arg}
	make && make install
	if [ $? = "0" ];then
		diy_echo "openresty安装成功." "${info} "
	else
		diy_echo "openresty安装失败!!!" "${red}" "${error}"
		exit 1
	fi

}

openresty_config(){
	conf_dir=${home_dir}/conf
	cat ${workdir}/config/nginx.conf >${conf_dir}/nginx.conf

	add_log_cut openresty ${home_dir}/logs/*.log
}

add_openresty_service(){

	Type="forking"
	ExecStart="${home_dir}/bin/openresty -c ${home_dir}/nginx/conf/nginx.conf"
	ExecReload="${home_dir}/bin/openresty -s reload"
	ExecStop="${home_dir}/bin/openresty -s stop"
	conf_system_service
	add_system_service openresty ${home_dir}/init
}

openresty_install_ctl(){
	openresty_env_load
	select_version
	install_dir_set
	online_version
	online_down_file
	unpacking_file
	dependent_install
	openresty_compile
	openresty_config
	add_openresty_service
	clear_install
}