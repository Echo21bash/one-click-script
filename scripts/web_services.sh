#!/bin/bash

tomcat_set(){
	input_option "请输入部署个数" "1" "tomcat_num"
	[[ ${tomcat_num} > 1 ]] && diy_echo "部署多个tomcat服务一定要避免端口冲突" "${yellow}" "${warning}"
}

tomcat_other_set(){
		input_option "设置Tomcat文件夹名称,注意不要和现有的冲突" "tomcat" "home_dir_name"
		home_dir_name=${input_value}
		input_option "请输入service服务名称" "tomcat" "service_name"
		service_name=${input_value}
		input_option "请输入http端口号" "8080" "http_port"

}

tomcat_install(){

	for ((i=1;i<=tomcat_num;i++));
	do
		echo -e "${info} 开始设置第${i}个Tomcat."
		tomcat_other_set
		home_dir=${install_dir}/${home_dir_name}
		[ ! -d ${home_dir} ] && mkdir -p ${home_dir}
		\cp -rp ${tar_dir}/* ${install_dir}/${home_dir_name}
		tomcat_config
		tomcat_manager_config
		memory_overflow_config
		add_tomcat_service
		echo -e "${info} 好的设置好${i}个Tomcat了."
	done

}

tomcat_config(){
	#修改配置参数
	sed -i '/<Connector port="8080" protocol="HTTP\/1.1"/,/redirectPort="8443" \/>/s/redirectPort="8443" \/>/redirectPort="8443"/' ${home_dir}/conf/server.xml
	sed -i '/^               redirectPort="8443"$/r '${workdir}'/config/tomcat_service.txt' ${home_dir}/conf/server.xml
	sed -i '/<\/Host>/i \      <!--<Context path="" docBase="" reloadable="true">\n      <\/Context>-->' ${home_dir}/conf/server.xml

	#禁用shutdown端口
	sed -i 's/<Server port="8005"/<Server port="-1"/' ${home_dir}/conf/server.xml
	#注释AJP
	sed -i 's#<Connector port="8009".*#<!-- <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" /> -->#' ${home_dir}/conf/server.xml
	#修改http端口
	sed -i 's/<Connector port="8080"/<Connector port="'${http_port}'"/' ${home_dir}/conf/server.xml
	#日志切割
	add_log_cut ${home_dir_name} ${home_dir}/logs/catalina.out
}

tomcat_manager_config(){
	N=`cat -n ${home_dir}/conf/tomcat-users.xml | grep '</tomcat-users>' | awk '{print $1}'`
	sed -i ''$N'i<role rolename="manager-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<role rolename="admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<user username="admin" password="admin" roles="manager-gui,admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
}

check_java_version(){

	java_version=$(java -version 2>&1 | grep -Eo [0-9.]+_[0-9]+ | awk 'NR==1{print}' | grep -Eo '[0-9]{1}\.[0-9]{1}')
	if [[ -z ${java_version} ]];then
		diy_echo "检测到java环境未安装" "${yellow}" "${error}"
		java_install_ctl
	fi

}

memory_overflow_config(){

	N=`grep -n '^# OS' ${home_dir}/bin/catalina.sh | awk -F ':' '{print $1}'`
	sed -i "$N i# JAVA_OPTS (Optional) Java runtime options used when any command is executed.\n" ${home_dir}/bin/catalina.sh
	
	if [[ ${java_version} < '1.8' ]];then
		sed -i "/^# JAVA_OPTS.*/r ${workdir}/config/tomcat_jvm7.txt" ${home_dir}/bin/catalina.sh
	else
		sed -i "/^# JAVA_OPTS.*/r ${workdir}/config/tomcat_jvm8.txt" ${home_dir}/bin/catalina.sh
	fi
}

add_tomcat_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/startup.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service ${service_name} ${home_dir}/init
}

tomcat_install_ctl(){
	install_version tomcat
	install_selcet
	tomcat_set
	install_dir_set
	download_unzip
	tomcat_install
	clear_install
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
	yum -y install make zlib zlib-devel gcc-c++ libtool  openssl openssl-devel pcre pcre-devel
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

nginx_compile(){
	cd ${tar_dir}
	if [[ x${add_module[*]} = 'x' ]];then
		configure_arg="--prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module"
	fi
	if [[ ${add_module[*]} =~ '1' ]];then
		diy_echo "请确保正确配置/etc/fdfs/mod_fastdfs.conf并启动fsatdfs,否则会无法访问文件！" "${yellow}" "${warning}"
		axel -n 24 -a https://codeload.github.com/happyfish100/libfastcommon/tar.gz/master -o libfastcommon-master.tar.gz && tar -zxf libfastcommon-master.tar.gz
		cd libfastcommon-master
		./make.sh  && ./make.sh install
		if [[ $? = '0' ]];then
			diy_echo "libfastcommon安装完成." "" "${info}"
			cd ..
		else
			diy_echo "libfastcommon安装失败." "${yellow}" "${error}"
			exit
		fi
		wget https://codeload.github.com/happyfish100/fastdfs-nginx-module/zip/master -O fastdfs-nginx-module-master.zip && unzip -o fastdfs-nginx-module-master.zip
		
		configure_arg="${configure_arg} --add-module=${tar_dir}/${add_module_value}-master/src"
		#sed -i 's///'
	if [[ ${add_module[*]} =~ '2' ]];then
		wget https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz -O nginx_upstream_check_module-master.tar.gz && tar zxf nginx_upstream_check_module-master.tar.gz
		patch -p1 < ${tar_dir}/${add_module_value}-master/check.patch
		configure_arg="${configure_arg} --add-module=${tar_dir}/${add_module_value}-master"
	fi
	./configure ${configure_arg}
	make && make install
	if [ $? = "0" ];then
		echo -e "${info} nginx安装成功."
	else
		echo -e "${error} nginx安装失败!!!"
		exit 1
	fi

}

nginx_config(){
	conf_dir=${home_dir}/conf
	cat ${workdir}/config/nginx.conf >${conf_dir}/nginx.conf
	\cp ${tar_dir}/${add_module_value}-master/src/mod_fastdfs.conf /etc/fdfs/
	add_log_cut nginx ${home_dir}/logs/*.log
}

add_nginx_service(){

	Type="forking"
	ExecStart="${home_dir}/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/sbin/nginx -s reload"
	ExecStop="${home_dir}/sbin/nginx -s stop"
	conf_system_service
	add_system_service nginx ${home_dir}/init
}

nginx_install_ctl(){
	install_version nginx
	install_selcet
	nginx_install_set
	install_dir_set
	download_unzip
	nginx_install
	nginx_compile
	nginx_config
	add_nginx_service
	clear_install
}