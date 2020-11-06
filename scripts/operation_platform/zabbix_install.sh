#!/bin/bash

zabbix_env_load(){
	tmp_dir=/tmp/zabbix_tmp
	soft_name=zabbix
	program_version=('4.0' '5.0')
	url='https://mirrors.yangxingzhen.com/zabbix'
	select_version
	install_dir_set
	online_version	

}

zabbix_down(){
	down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/${soft_name}-${detail_version_number}.tar.gz ${tmp_dir}
}

zabbix_set(){
	output_option "请选择要安装的模块" "zabbix-server zabbix-agent zabbix-java zabbix-proxy" "install_module"
	install_module_value=(${output_value[@]})
	module_configure=$(echo ${install_module_value[@]} | sed s/zabbix/--enable/g)
	if [[ ${install_module_value[@]} =~ 'zabbix-server' ]];then
		diy_echo "现在设置zabbix-server相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的数据库地址" "127.0.0.1" "zabbix_db_host"
		zabbix_db_host=${input_value}
		input_option "请输入要连接的数据库端口" "3306" "zabbix_db_port"
		input_option "请输入要连接的数据库名" "zabbix" "zabbix_db_name"
		zabbix_db_name=${input_value}
		input_option "请输入要连接的数据库用户" "root" "zabbix_db_user"
		zabbix_db_user=${input_value}
		input_option "请输入要连接的数据库密码" "123456" "zabbix_db_passwd"
		zabbix_db_passwd=${input_value}
	fi
	if [[ ${install_module_value[@]} =~ 'zabbix-agent' ]];then
		diy_echo "现在设置zabbix-agent相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的zabbix-server地址" "127.0.0.1" "zabbix_server_host"
		zabbix_server_host=${input_value}
		input_option "请设置zabbix-agent的主机名地址" "zabbix_server" "zabbix_agent_host_name"
		zabbix_agent_host_name=${input_value}
	fi
	if [[ ${install_module_value[@]} =~ 'zabbix-java' ]];then
		echo
	fi
}

zabbix_install(){

	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	if [[ ${install_module_value[@]} =~ 'zabbix-server' || ${install_module_value[@]} =~ 'zabbix-proxy' ]];then
		yum -y install gcc make net-snmp-devel libxml2-devel libcurl-devel mysql-devel libevent-devel
		./configure --prefix=${home_dir} ${module_configure} --with-mysql --with-net-snmp --with-libcurl --with-libxml2
	else
		yum -y install gcc make net-snmp-devel libxml2-devel libcurl-devel libevent-devel
		./configure --prefix=${home_dir} ${module_configure} --with-net-snmp --with-libcurl --with-libxml2
	fi
	cd ${tar_dir}
	home_dir=${install_dir}/zabbix
	mkdir -p ${home_dir}
	
	make && make install
	if [ $? = '0' ];then
		diy_echo "编译完成..." "" "${info}"
	else
		diy_echo "编译失败!" "" "${error}"
		exit 1
	fi

}

zabbix_config(){

	groupadd zabbix >/dev/null 2>&1
	useradd zabbix -M -g zabbix -s /bin/false >/dev/null 2>&1
	mkdir -p ${home_dir}/logs
	chown -R zabbix.zabbix ${home_dir}/logs
	if [[ ${install_module_value[@]} =~ 'zabbix-server' ]];then
	
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_server.log#' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_server.pid@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBHost=.*@DBHost='${zabbix_db_host}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBName=.*@DBName='${zabbix_db_name}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBUser=.*@DBUser='${zabbix_db_user}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPassword=.*@DBPassword='${zabbix_db_passwd}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPort=.*@DBPort='${zabbix_db_port}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_server.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_server.conf.d/*.conf@' ${home_dir}/etc/zabbix_server.conf
	fi
 
	if [[ ${install_module_value[@]} =~ 'zabbix-agent' ]];then

		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_agentd.pid@' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_agentd.log#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^ServerActive=.*#ServerActive='${zabbix_server_host}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Hostname=.*#Hostname='${zabbix_agent_host_name}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's@^# Timeout=.*@Timeout=20@' ${home_dir}/etc/zabbix_agentd.conf

		sed -i 's@^# Include=/usr/local/etc/zabbix_agentd.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_agentd.conf.d/*.conf@' ${home_dir}/etc/zabbix_agentd.conf
	fi
	if [[ ${install_module_value[@]} =~ 'zabbix-java' ]];then
		sed -i 's@^PID_FILE=.*@PID_FILE='${home_dir}'/logs/zabbix_java.pid@' ${home_dir}/sbin/zabbix_java/settings.sh
		sed -i 's@/tmp/zabbix_java.log@'${home_dir}'/logs/zabbix_java.log@' ${home_dir}/sbin/zabbix_java/lib/logback.xml
	fi

}

add_zabbix_service(){
	Type="forking"
	if [[ ${install_module_value[@]} =~ 'zabbix-server' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_server.conf"
		PIDFile="${home_dir}/logs/zabbix_server.pid"
		ExecStart="${home_dir}/sbin/zabbix_server -c \$CONFFILE"
		conf_system_service ${home_dir}/zabbix-serverd
		add_system_service zabbix-serverd ${home_dir}/zabbix-serverd
	fi
	if [[ ${install_module_value[@]} =~ 'zabbix-agent' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_agentd.conf"
		PIDFile="${home_dir}/logs/zabbix_agentd.pid"
		ExecStart="${home_dir}/sbin/zabbix_agentd -c \$CONFFILE"
		conf_system_service ${home_dir}/zabbix-agentd
		add_system_service zabbix-agentd ${home_dir}/zabbix-agentd
	fi
	if [[ ${install_module_value[@]} =~ 'zabbix-java' ]];then
		PIDFile="${home_dir}/logs/zabbix_java.pid"
		ExecStart="${home_dir}/sbin/zabbix_java/startup.sh"
		conf_system_service ${home_dir}/zabbix-java-gateway
		add_system_service zabbix-java-gateway ${home_dir}/zabbix-java-gateway
	fi
}

zabbix_install_ctl(){
	zabbix_env_load
	zabbix_set
	zabbix_down
	zabbix_install
	zabbix_config
	add_zabbix_service
	clear_install
}
