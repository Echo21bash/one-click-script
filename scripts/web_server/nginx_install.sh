#!/bin/bash

nginx_env_load(){
	tmp_dir=/usr/local/src/nginx_tmp
	soft_name=nginx
	program_version=('1.14' '1.15' '1.16')
	url="https://repo.huaweicloud.com/nginx"
	select_version
	install_dir_set
	online_version
}

nginx_down(){
	down_url="${url}/nginx-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/nginx-${detail_version_number}.tar.gz ${tmp_dir}
}

nginx_install_set(){
	input_option '是否添加额外模块' 'n' 'add'
	add=${input_value}
	yes_or_no ${add}
	if [[ $? = '0' ]];then
		output_option '选择要添加的模块' 'fastdfs-nginx-module nginx_upstream_check_module' 'add_module'
		add_module_value=${output_value}
	fi
}

nginx_install(){

	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum -y install make zlib zlib-devel gcc-c++ libtool  openssl openssl-devel pcre pcre-devel patch GeoIP-devel
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

nginx_compile(){
	home_dir=${install_dir}/nginx
	mkdir -p ${home_dir}
	cd ${tar_dir}
	configure_arg="--prefix=${home_dir} --group=nginx --user=nginx  --with-pcre --with-stream --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-http_geoip_module --with-stream_ssl_module"
	if [[ ${add_module[*]} =~ '1' ]];then
		diy_echo "请确保正确配置/etc/fdfs/mod_fastdfs.conf并启动fsatdfs,否则会无法访问文件！" "${yellow}" "${warning}"
		down_file https://github.com/happyfish100/libfastcommon/archive/refs/tags/V1.0.53.tar.gz V1.0.53.tar.gz && tar -zxf V1.0.53.tar.gz
		cd libfastcommon-1.0.53
		./make.sh  && ./make.sh install
		if [[ $? = '0' ]];then
			diy_echo "libfastcommon安装完成." "" "${info}"
			cd ..
		else
			diy_echo "libfastcommon安装失败." "${yellow}" "${error}"
			exit
		fi
		down_file https://github.com/happyfish100/fastdfs-nginx-module/archive/master.tar.gz fastdfs-nginx-module-master.tar.gz && tar zxf fastdfs-nginx-module-master.tar.gz
		
		configure_arg="${configure_arg} --add-module=${tar_dir}/${add_module_value}-master/src"
		sed -i 's#ngx_module_incs=.*#ngx_module_incs="/usr/include/fastdfs /usr/include/fastcommon/"#' ${tar_dir}/${add_module_value}-master/src/config
		sed -i 's#CORE_INCS=.*#CORE_INCS="$CORE_INCS /usr/include/fastdfs /usr/include/fastcommon/"#' ${tar_dir}/${add_module_value}-master/src/config
	fi
	if [[ ${add_module[*]} =~ '2' ]];then
		down_file https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz nginx_upstream_check_module-master.tar.gz && tar zxf nginx_upstream_check_module-master.tar.gz
		[[ ${online_select_version} > nginx-1.13.99 && ${online_select_version} < nginx-1.16.1 ]] && patch -p1 < ${tar_dir}/${add_module_value}-master/check_1.14.0+.patch
		[[ ${online_select_version} > nginx-1.16.0 ]] && patch -p1 < ${tar_dir}/${add_module_value}-master/check_1.16.1+.patch
		
		configure_arg="${configure_arg} --add-module=${tar_dir}/${add_module_value}-master"
	fi
	./configure ${configure_arg}
	make && make install
	if [ $? = "0" ];then
		mkdir -p ${home_dir}/conf.d
		echo -e "${info} nginx安装成功."
	else
		echo -e "${error} nginx安装失败!!!"
		exit 1
	fi

}

nginx_config(){
	conf_dir=${home_dir}/conf
	\cp ${workdir}/config/nginx/nginx.conf ${conf_dir}/
	\cp ${workdir}/config/nginx/default.conf ${home_dir}/conf.d
	sed -i "s#conf.d#${home_dir}/conf.d#" ${conf_dir}/nginx.conf
	if [[ ${add_module[*]} =~ '1' ]];then
		\cp ${tar_dir}/${add_module_value}-master/src/mod_fastdfs.conf /etc/fdfs/
	fi
	add_log_cut ${tmp_dir}/log_cut_nginx ${home_dir}/logs/*.log
	\cp ${tmp_dir}/log_cut_nginx /etc/logrotate.d
}

add_nginx_service(){

	Type="forking"
	ExecStart="${home_dir}/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/sbin/nginx -s reload"
	ExecStop="${home_dir}/sbin/nginx -s stop"
	add_daemon_file	${home_dir}/init
	add_system_service nginx ${home_dir}/init
}

nginx_install_ctl(){
	nginx_env_load
	nginx_install_set
	nginx_down
	nginx_install
	nginx_compile
	nginx_config
	add_nginx_service
	
}