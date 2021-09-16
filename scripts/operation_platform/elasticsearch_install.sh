#!/bin/bash

elasticsearch_env_load(){
	tmp_dir=/usr/local/src/elasticsearch_tmp
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
		elasticsearch_master_node_list
		elasticsearch_master_server_list
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
				useradd -M elasticsearch
				mkdir -p ${install_dir}/elasticsearch-node${service_id}
				mkdir -p ${elsearch_data_dir}/node${service_id}
				"
				info_log "正在向节点${now_host}分发elsearch-node${service_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/elasticsearch-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{elasticsearch-node${i}.service,} ${host_ip[$k]}:${install_dir}/elasticsearch-node${service_id}
				
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				chown -R elasticsearch.elasticsearch ${install_dir}/elasticsearch-node${service_id}
				\cp ${install_dir}/elasticsearch-node${service_id}/elasticsearch-node${i}.service /etc/systemd/system/elasticsearch-node${i}.service
				systemctl daemon-reload
				"
				((i++))
			done
			((k++))
		done
	fi

}

elasticsearch_master_server_list(){
	local i=1
	local k=0
	for now_host in ${host_ip[@]}
	do
		elsearch_tcp_port=9300
		for ((j=0;j<${node_num[$k]};j++))
		do
			service_id=$i
			if [[ ${service_id} > "${master_nodes_num}" ]];then
				break
			fi
			let elsearch_tcp_port=${elsearch_tcp_port}+$j
			discovery_hosts="${now_host}:${elsearch_tcp_port},${discovery_hosts}"

			((i++))
		done
		((k++))
	done

}

elasticsearch_master_node_list(){
	###节点总数
	node_total_num=0
	for num in ${node_num[@]}
	do
		let node_total_num=${node_total_num}+${num}
	done
	###未指定主节点数量时将所有节点同时配置为数据节点和主节点
	if [[ -z ${master_nodes_num} ]];then
		master_nodes_num=${node_total_num}
		data_nodes_num=${node_total_num}
		local j=0
		for ((i=1;i<=${node_total_num};i++))
		do
			service_id=$i
			master_nodes="node${service_id},${master_nodes}"
			master_nodes_list[$j]="node${service_id}"
			data_nodes_list[$j]="node${service_id}"
			((j++))
		done
	fi
	###指定主节点数量后主节点不存储数据，其余节点配置为数据节点
	if [[ -n ${master_nodes_num} ]];then
		local j=0
		local k=0
		for ((i=1;i<=${node_total_num};i++))
		do
			if [[ $i -le ${master_nodes_num} ]];then
				service_id=$i
				master_nodes="node${service_id},${master_nodes}"
				master_nodes_list[$j]="node${service_id}"
				((j++))
			else
				service_id=$i
				data_nodes_list[$k]="node${service_id}"
				((k++))
			fi
		done
	fi




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
		###集群相关参数配置
		sed -i "s/#cluster.name.*/cluster.name: ${cluster_name}/" ${conf_dir}/elasticsearch.yml
		sed -i "/cluster.name.*/acluster.max_shards_per_node: 100000" ${conf_dir}/elasticsearch.yml
		###节点参数配置
		sed -i "s/#node.name.*/node.name: node${service_id}\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		if [[ ${master_nodes_list[@]} =~ "node${service_id}" ]];then
			sed -i "/node.name.*/anode.master: true\nnode.data: false" ${conf_dir}/elasticsearch.yml
		fi
		if [[ ${data_nodes_list[@]} =~ "node${service_id}" ]];then
			sed -i "/node.name.*/anode.master: false\nnode.data: true" ${conf_dir}/elasticsearch.yml
		fi		
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${now_host}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		###JVM内存配置
		sed -i "s/## -Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/## -Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/-Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
		if [[ ${version_number} < 6 ]]; then
			sed -i "s/#discovery.zen.ping.unicast.hosts:.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]/" ${conf_dir}/elasticsearch.yml
        else
			sed -i "s/#discovery.seed_hosts:.*/discovery.seed_hosts: ${discovery_hosts}/" ${conf_dir}/elasticsearch.yml
			sed -i "s/#cluster.initial_master_nodes:.*/cluster.initial_master_nodes: ${master_nodes}/" ${conf_dir}/elasticsearch.yml
        fi
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
	
}
