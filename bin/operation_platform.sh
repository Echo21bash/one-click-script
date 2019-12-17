#!/bin/bash

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${output_value[@]} =~ 'elasticsearch' ]];then
		elasticsearch_install_ctl
	elif [[ ${output_value[@]} =~ 'logstash' ]];then
		logstash_install_ctl
	elif [[ ${output_value[@]} =~ 'kibana' ]];then
		kibana_install_ctl
	elif [[ ${output_value[@]} =~ 'filebeat' ]];then
		filebeat_install_ctl
	fi	
}

elasticsearch_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	else
		input_option "请输入部署总个数($(diy_echo 必须是奇数 $red))" "3" "deploy_num_total"
		input_option '请输入所有部署elsearch的机器的ip地址,第一个为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'elsearch_ip'
		elsearch_ip=(${input_value[@]})
		input_option '请输入每台机器部署elsearch的个数,第一个为本机部署个数(多个使用空格分隔)' '2 1' 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}
		diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	fi
}

elasticsearch_install(){

	useradd -M elsearch
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir}/* ${home_dir}
		chown -R elsearch.elsearch ${home_dir}
		elasticsearch_conf
		add_elasticsearch_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		elasticsearch_server_list
		chown -R elsearch.elsearch ${tar_dir}
		for ((i=1;i<=${deploy_num_local};i++))
		do
			\cp -rp ${tar_dir} ${install_dir}/elsearch-node${i}
			home_dir=${install_dir}/elsearch-node${i}
			elasticsearch_conf
			add_elasticsearch_service
			elsearch_port=$((${elsearch_port}+1))
			elsearch_tcp_port=$((${elsearch_tcp_port}+1))
		done
	fi

}

elasticsearch_server_list(){

	local i
	local j
	local g
	j=0
	g=0

	for ip in ${elsearch_ip[@]}
	do
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				discovery_hosts[$g]="\"${elsearch_ip[$j]}:$(((elsearch_tcp_port+$i)))\","
				g=$(((${g}+1)))
			done	
		done
		j=$(((${j}+1)))
	done
	#将最后一个值得逗号去掉
	discovery_hosts[$g-1]=$(echo ${discovery_hosts[$g-1]} | grep -Eo "[\"\.0-9:]{1,}")
	discovery_hosts=$(echo ${discovery_hosts[@]})
}

elasticsearch_conf(){
	get_ip
	if [[ ${deploy_mode} = '1' ]];then
		conf_dir=${home_dir}/config
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
	else
		conf_dir=${home_dir}/config

		sed -i "s/#cluster.name.*/cluster.name: my-elsearch-cluster/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#node.name.*/node.name: ${local_ip}_node${i}\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#discovery.zen.ping.unicast.hosts.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]\ndiscovery.zen.ping_timeout: 30s/" ${conf_dir}/elasticsearch.yml
		sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
	fi

}

add_elasticsearch_service(){
	Type=forking
	User=elsearch
	ExecStart="${home_dir}/bin/elasticsearch"
	ARGS="-d"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service elsearch ${home_dir}/init
	else
		add_system_service elsearch-node${i} ${home_dir}/init
	fi
}

elasticsearch_install_ctl(){
	install_version elasticsearch
	install_selcet
	elasticsearch_install_set
	install_dir_set
	download_unzip
	elasticsearch_install
	clear_install
}

logstash_install_set(){
echo
}

logstash_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/config.d
	logstash_conf
	add_logstash_service
}

logstash_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
	sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
	sed -i "s@# path.config.*@path.config: ${home_dir}/config.d@" ${conf_dir}/logstash.yml
	sed -i "s/# http.host.*/http.host: \"${local_ip}\" " ${conf_dir}/logstash.yml
	sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
	sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
}

add_logstash_service(){
	Type=simple
	ExecStart="${home_dir}/bin/logstash"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service logstash ${home_dir}/init
}

logstash_install_ctl(){
	install_version logstash
	install_selcet
	logstash_install_set
	install_dir_set
	download_unzip
	logstash_install
	clear_install
}

kibana_install_set(){
	input_option "输入http端口号" "5601" "kibana_port"
	input_option "输入elasticsearch服务http地址" "127.0.0.1:9200" "elasticsearch_ip"
	elasticsearch_ip=${input_value}
}

kibana_install(){
	
	mv ${tar_dir}/* ${home_dir}
	kibana_conf
	add_kibana_service
}

kibana_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/#server.port.*/server.port: ${kibana_port}/" ${conf_dir}/kibana.yml
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s@#elasticsearch.url.*@elasticsearch.url: http://${elasticsearch_ip}@" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	ExecStart="${home_dir}/bin/kibana"
	conf_system_service 
	add_system_service kibana ${home_dir}/kibana_init
}

kibana_install_ctl(){
	install_version kibana
	install_selcet
	kibana_install_set
	install_dir_set
	download_unzip
	kibana_install
	clear_install
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
	install_version filebeat
	install_selcet
	#filebeat_install_set
	install_dir_set
	download_unzip
	filebeat_install
	clear_install
}

zabbix_set(){
	output_option "请选择要安装的模块" "zabbix-server zabbix-agent zabbix-java zabbix-proxy" "install_module"
	install_module_value=(${output_value[@]})
	module_configure=$(echo ${install_module_value[@]} | sed s/zabbix/--enable/g)
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
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
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		diy_echo "现在设置zabbix-agent相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的zabbix-server地址" "127.0.0.1" "zabbix_server_host"
		zabbix_server_host=${input_value}
		input_option "请设置zabbix-agent的主机名地址" "zabbix_server" "zabbix_agent_host_name"
		zabbix_agent_host_name=${input_value}
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		echo
	fi
}

zabbix_install(){

	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	yum -y install net-snmp-devel libxml2-devel libcurl-devel mysql-devel libevent-devel
	cd ${tar_dir}
	./configure --prefix=${home_dir} ${module_configure} --with-mysql --with-net-snmp --with-libcurl --with-libxml2
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
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
	
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_server.log#' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_server.pid@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBHost=.*@DBHost='${zabbix_db_host}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBName=.*@DBName='${zabbix_db_name}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBUser=.*@DBUser='${zabbix_db_user}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPassword=.*@DBPassword='${zabbix_db_passwd}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPort=.*@DBPort='${zabbix_db_port}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_server.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_server.conf.d/*.conf@' ${home_dir}/etc/zabbix_server.conf
	fi
 
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then

		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_agentd.pid@' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_agentd.log#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Server=.*#Server='${zabbix_server_host}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Hostname=.*#Hostname='${zabbix_agent_host_name}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_agentd.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_agentd.conf.d/*.conf@' ${home_dir}/etc/zabbix_agentd.conf
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		sed -i 's@^PID_FILE=.*@PID_FILE='${home_dir}'/logs/zabbix_java.pid@' ${home_dir}/sbin/zabbix_java/settings.sh
		sed -i 's@/tmp/zabbix_java.log@'${home_dir}'/logs/zabbix_java.log@' ${home_dir}/sbin/zabbix_java/lib/logback.xml
	fi

}

add_zabbix_service(){
	Type="forking"
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_server.conf"
		PIDFile="${home_dir}/logs/zabbix_server.pid"
		ExecStart="${home_dir}/sbin/zabbix_server -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-serverd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_agentd.conf"
		PIDFile="${home_dir}/logs/zabbix_agentd.pid"
		ExecStart="${home_dir}/sbin/zabbix_agentd -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-agentd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		PIDFile="${home_dir}/logs/zabbix_java.pid"
		ExecStart="${home_dir}/sbin/zabbix_java/startup.sh"
		conf_system_service
		add_system_service zabbix-java-gateway ${home_dir}/init
	fi
}

zabbix_install_ctl(){
	install_version zabbix
	install_selcet
	zabbix_set
	install_dir_set
	download_unzip
	zabbix_install
	zabbix_config
	add_zabbix_service
	clear_install
}

rhcs_install_set(){
	input_option "输入集群名称" "ha_cluster" "cluster_name"
	cluster_name=${input_value}
	diy_echo "首先配置管理主机免密登录各节点" "${yellow}" "${info}" 
	auto_ssh_keygen
	node_name=(${host_name[@]})
}

rhcs_install_ctl(){
	if [[ ${os_release} = 6 ]];then
		yum install -y pacemaker
	fi
	if [[ ${os_release} = 7 ]];then
		yum install -y pacemaker pcs
	fi

}