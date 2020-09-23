#!/bin/bash

elasticsearch_env_load(){
	tmp_dir=/tmp/elasticsearch_tmp
	soft_name=elasticsearch
	program_version=('5.6' '6.1' '6.2')
	url='https://mirrors.huaweicloud.com/elasticsearch'
	down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz'

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
	elasticsearch_env_load
	elasticsearch_install_set
	select_version
	install_dir_set
	online_version
	online_down_file
	unpacking_file
	elasticsearch_install
	clear_install
}
