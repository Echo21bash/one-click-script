#!/bin/bash

elasticsearch_env_load(){
	tmp_dir=/tmp/elasticsearch_tmp
	soft_name=elasticsearch
	program_version=('5' '6' '7')
	url='https://mirrors.huaweicloud.com/elasticsearch'
	select_version
	install_dir_set
	online_version	

}

elasticsearch_down(){
	if [[ ${version_number} = '7' ]];then
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz"
	else
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz"
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

elasticsearch_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	else
		vi ${workdir}/config/elk/elastic.conf
		. ${workdir}/config/elk/elastic.conf
	fi
}

elasticsearch_install(){

	if [[ ${deploy_mode} = '1' ]];then
		useradd -M elasticsearch
		home_dir=${install_dir}/elasticsearch
		mkdir -p ${install_dir}/elasticsearch
		mv ${tar_dir}/* ${home_dir}
		chown -R elasticsearch.elasticsearch ${home_dir}
		elasticsearch_conf
		add_elasticsearch_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
		elasticsearch_server_list
		
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			elsearch_port=9200
			elsearch_tcp_port=9300
			for ((j=0;j<${node_num[$k]};j++))
			do
				service_id=$i
				let elsearch_port=9200+$j
				let elsearch_tcp_port=9300+$j
				elasticsearch_conf
				home_dir=${install_dir}/elasticsearch-node${service_id}
				add_elasticsearch_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${install_dir}/elasticsearch-node${service_id}
				mkdir -p ${elsearch_data_dir}/node${service_id}
				"
				info_log "正在向节点${now_host}分发elsearch-node${service_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/elasticsearch-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{elasticsearch-node${i}.service,} ${host_ip[$k]}:${install_dir}/elasticsearch-node${service_id}
				
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${install_dir}/elasticsearch-node${service_id}/elasticsearch-node${i}.service /etc/systemd/system/elasticsearch-node${i}.service
				systemctl daemon-reload
				"
				((i++))
			done
			((k++))
		done
	fi

}

elasticsearch_server_list(){
	local i=1
	local k=0
	for now_host in ${host_ip[@]}
	do
		elsearch_tcp_port=9300
		for ((j=0;j<${node_num[$k]};j++))
		do
			service_id=$i
			let elsearch_tcp_port=${elsearch_tcp_port}+$j
			if [[ ${service_id} = '1' ]];then
				discovery_hosts=
			fi
			discovery_hosts="${now_host}:${elsearch_tcp_port},${discovery_hosts}"
			((i++))
		done
		((k++))
	done

}

elasticsearch_conf(){
	get_ip
	if [[ ${deploy_mode} = '1' ]];then
		conf_dir=${home_dir}/config
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
	else
		conf_dir=${tar_dir}/config
		if [[ ! -f ${conf_dir}/elasticsearch.yml.bak ]];then
			cp ${conf_dir}/elasticsearch.yml ${conf_dir}/elasticsearch.yml.bak
		fi
		\cp ${conf_dir}/elasticsearch.yml.bak ${conf_dir}/elasticsearch.yml
		sed -i "s/#cluster.name.*/cluster.name: ${cluster_name}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#node.name.*/node.name: node${service_id}\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${now_host}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#discovery.seed_hosts:.*/discovery.seed_hosts: ${discovery_hosts}\ndiscovery.zen.ping_timeout: 30s/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#discovery.zen.ping.unicast.hosts.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]\ndiscovery.zen.ping_timeout: 30s/" ${conf_dir}/elasticsearch.yml
		sed -i "s/## -Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/## -Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
	fi

}

add_elasticsearch_service(){
	if [[ ${deploy_mode} = '1' ]];then
		JAVA_HOME=${JAVA_HOME}
	else
		JAVA_HOME=`ssh ${host_ip[$k]} -p ${ssh_port[$k]} 'echo $JAVA_HOME'`
	fi
	if [[ ${version_number} > '6' && x${JAVA_HOME} = 'x' ]];then
		JAVA_HOME=${home_dir}/jdk
	fi

	Type=forking
	User=elasticsearch
	ExecStart="${home_dir}/bin/elasticsearch"
	ARGS="-d"
	Environment="JAVA_HOME=${JAVA_HOME}"
	if [[ ${deploy_mode} = '1' ]];then
		conf_system_service ${home_dir}/elasticsearch.service
		add_system_service elasticsearch ${home_dir}/elasticsearch.service
	else
		conf_system_service ${tmp_dir}/elasticsearch-node${service_id}.service
	fi
}

elasticsearch_install_ctl(){
	elasticsearch_env_load
	elasticsearch_install_set
	elasticsearch_down
	elasticsearch_install
	clear_install
}
