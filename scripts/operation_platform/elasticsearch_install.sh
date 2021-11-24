#!/bin/bash

elasticsearch_env_load(){
	tmp_dir=/usr/local/src/elasticsearch_tmp
	soft_name=elasticsearch
	program_version=('5' '6' '7')
	url='https://repo.huaweicloud.com/elasticsearch'
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
		vi ${workdir}/config/elk/elastic-single.conf
		. ${workdir}/config/elk/elastic-single.conf
	else
		vi ${workdir}/config/elk/elastic-cluster.conf
		. ${workdir}/config/elk/elastic-cluster.conf
	fi
}

elasticsearch_run_env_check(){

	if [[ ${deploy_mode} = '1' ]];then
		###修改内核参数
		[[ `sysctl -n vm.max_map_count` -lt "262144" ]] && echo 'vm.max_map_count = 262144'>>/etc/sysctl.conf && sysctl -w vm.max_map_count=262144
		if [[ ${version_number} < '7' ]];then
			###检测JDK环境
			java_status=`${JAVA_HOME}/bin/java -version > /dev/null 2>&1 && echo javaok`
			if [[ ${java_status} = "javaok" ]];then
				success_log "java运行环境已就绪"
			else
				error_log "java运行环境未就绪"
				exit 1
			fi
			
		else
			JAVA_HOME=${home_dir}/jdk
		fi
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local k=0
		for now_host in ${host_ip[@]}
		do
			###修改内核参数
			auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			[[ `sysctl -n vm.max_map_count` -lt "262144" ]] && echo 'vm.max_map_count = 262144'>>/etc/sysctl.conf && sysctl -w vm.max_map_count=262144
			EOF" "${passwd[$k]}"
			if [[ ${version_number} < '7' ]];then
				###检测JDK环境
				java_status=`auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && echo javaok
				EOF" "${passwd[$k]}"`
				if [[ ${java_status} =~ "javaok" ]];then
					success_log "主机${host_ip[$k]}java运行环境已就绪"
				else
					error_log "主机${host_ip[$k]}java运行环境未就绪"
					exit 1
				fi		
			else
				JAVA_HOME=${home_dir}/jdk
			fi

			((k++))
		done
	fi
}

elasticsearch_install(){

	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/elasticsearch
		elasticsearch_run_env_check
		elasticsearch_down
		useradd -M elasticsearch
		mkdir -p ${install_dir}/elasticsearch
		\cp -rp ${tar_dir}/* ${home_dir}
		chown -R elasticsearch.elasticsearch ${home_dir}
		elasticsearch_conf
		add_elasticsearch_service
		service_control elasticsearch start
		elasticsearch_cluster_check
	fi
	if [[ ${deploy_mode} = '2' ]];then
		elasticsearch_run_env_check
		elasticsearch_down
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

				info_log "正在向节点${now_host}分发elsearch-node${service_id}安装程序和配置文件..."
				auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				useradd -M elasticsearch
				mkdir -p ${install_dir}/elasticsearch-node${service_id}
				mkdir -p ${elsearch_data_dir}/node${service_id}
				EOF
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/elasticsearch-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				. /tmp/public.sh
				chown -R elasticsearch.elasticsearch ${install_dir}/elasticsearch-node${service_id}
				Type=simple
				User=elasticsearch
				ExecStart="${home_dir}/bin/elasticsearch"
				Environment="JAVA_HOME=${JAVA_HOME}"
				SuccessExitStatus="143"
				add_daemon_file ${home_dir}/elasticsearch-node${service_id}.service
				add_system_service elasticsearch-node${service_id} ${home_dir}/elasticsearch-node${service_id}.service
				service_control elasticsearch-node${service_id} enable
				service_control elasticsearch-node${service_id} restart
				rm -rf /tmp/public.sh
				EOF" "${passwd[$k]}"
				((i++))
			done
			((k++))
		done
		sleep 20
		elasticsearch_cluster_check
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
			discovery_hosts="\"${now_host}:${elsearch_tcp_port}\",${discovery_hosts}"

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
	###指定主节点数量后主节点不存储数据，其余节点配置为数据节点
	else
		if [[ -n ${master_nodes_num} && ${node_total_num} > ${master_nodes_num} ]];then
			data_nodes_num=$((node_total_num-master_nodes_num))
			local j=0
			local k=0
			for ((i=1;i<=${node_total_num};i++))
			do
				if [[ $i -le ${master_nodes_num} ]];then
					service_id=$i
					master_nodes="\"node${service_id}\",${master_nodes}"
					master_nodes_list[$j]="node${service_id}"
					((j++))
				else
					service_id=$i
					data_nodes_list[$k]="node${service_id}"
					((k++))
				fi
			done
		else
			error_log "主节点数不能大于总节点数"
			exit 1
		fi
	fi

	###最小启动的主节点数
	minimum_master_nodes="$(((master_nodes_num+1+1)/2))"
	###最小启动的数据节点数
	minimum_data_nodes="$(((data_nodes_num+1+1)/2))"

}

elasticsearch_conf(){
	get_ip
	if [[ ${deploy_mode} = '1' ]];then
		conf_dir=${home_dir}/config
		sed -i "s/#node.name.*/node.name: node1\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\n#bootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.system_call_filter.*/bootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: 0.0.0.0/" ${conf_dir}/elasticsearch.yml
		sed -i "/network.host:.*/adiscovery.type: single-node" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: 9200\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: 9300/" ${conf_dir}/elasticsearch.yml
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
		if [[ ${master_nodes_list[@]} =~ "node${service_id}" && ! ${data_nodes_list[@]} =~ "node${service_id}" ]];then
			sed -i "/node.name.*/anode.master: true\nnode.data: false" ${conf_dir}/elasticsearch.yml
		fi
		if [[ ${data_nodes_list[@]} =~ "node${service_id}" && ! ${master_nodes_list[@]} =~ "node${service_id}" ]];then
			sed -i "/node.name.*/anode.master: false\nnode.data: true" ${conf_dir}/elasticsearch.yml
		fi
		if [[ ${master_nodes_list[@]} =~ "node${service_id}" && ${data_nodes_list[@]} =~ "node${service_id}" ]];then
			sed -i "/node.name.*/anode.master: true\nnode.data: true" ${conf_dir}/elasticsearch.yml
		fi
		
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\n#bootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.system_call_filter.*/bootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: 0.0.0.0/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		###JVM内存配置
		sed -i "s/## -Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/## -Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/-Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
		###自动发现节点配置
		if [[ ${version_number} < 7 ]]; then
			sed -i "s/#discovery.zen.ping.unicast.hosts:.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]/" ${conf_dir}/elasticsearch.yml
			sed -i "/discovery.zen.ping.unicast.hosts:.*/adiscovery.zen.minimum_master_nodes: ${minimum_master_nodes}" ${conf_dir}/elasticsearch.yml
        else
			sed -i "s/#discovery.seed_hosts:.*/discovery.seed_hosts: [${discovery_hosts}]/" ${conf_dir}/elasticsearch.yml
			sed -i "/discovery.seed_hosts:.*/adiscovery.zen.minimum_master_nodes: ${minimum_master_nodes}" ${conf_dir}/elasticsearch.yml
			sed -i "s/#cluster.initial_master_nodes:.*/cluster.initial_master_nodes: [${master_nodes}]/" ${conf_dir}/elasticsearch.yml
        fi
        ###分片恢复需满足的条件
        sed -i "/#gateway.recover_after_nodes:.*/agateway.recover_after_master_nodes: ${minimum_master_nodes}" ${conf_dir}/elasticsearch.yml
        sed -i "/#gateway.recover_after_nodes:.*/agateway.recover_after_data_nodes: ${minimum_data_nodes}" ${conf_dir}/elasticsearch.yml
	fi

}

add_elasticsearch_service(){

	if [[ ${deploy_mode} = '1' ]];then
		Type=simple
		User=elasticsearch
		ExecStart="${home_dir}/bin/elasticsearch"
		Environment="JAVA_HOME=${JAVA_HOME}"
		SuccessExitStatus="143"
		add_daemon_file ${home_dir}/elasticsearch.service
		add_system_service elasticsearch ${home_dir}/elasticsearch.service
		service_control elasticsearch enable
		service_control elasticsearch restart
	fi
}


elasticsearch_cluster_check(){

	info_log "正在检测集群健康状态"
	if [[ ${deploy_mode} = '1' ]];then
		for (( i = 0; i < 60; i++ ))
		do
			sleep 2
			elasticsearch_status=`service_control elasticsearch is-active`
			if [[ ${elasticsearch_status} = 'active' ]];then
				curl http://127.0.0.1:9200 >/dev/null 2>&1
				if [[ $? = 0 ]];then
					elasticsearch_read=yes
					success_log "elasticsearch已就绪"
					break
				fi
			fi
		done
		if [[ ${elasticsearch_read} = 'yes' ]];then
			success_log "elasticsearch集群正常"
		else
			error_log "elasticsearch集群异常"
		fi
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			for ((j=0;j<${node_num[$k]};j++))
			do
				elasticsearch_status=`auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				systemctl is-active elasticsearch-node${i}
				EOF" "${passwd[$k]}"`
				if [[ ${elasticsearch_status} =~ "active" ]];then
					success_log "elasticsearch-node${i}启动完成"
				else
					error_log "elasticsearch-node${i}启动失败"
				fi
				((i++))
			done
			((k++))
		done

		for (( i = 0; i < 60; i++ ))
		do
			sleep 2
			elasticsearch_status=`auto_input_keyword "ssh ${host_ip[0]} -p ${ssh_port[0]} <<-EOF
			systemctl is-active elasticsearch-node1
			EOF" "${passwd[0]}"`
			if [[ ${elasticsearch_status} =~ "active" ]];then
				curl http://${host_ip[0]}:9200 >/dev/null 2>&1
				if [[ $? = 0 ]];then
					elasticsearch_read=yes
					success_log "elasticsearch已就绪"
					break
				fi
			fi
		done
		if [[ ${elasticsearch_read} = 'yes' ]];then
			success_log "elasticsearch集群正常"
		else
			error_log "elasticsearch集群异常"
		fi
	fi
}

elasticsearch_install_ctl(){
	elasticsearch_env_load
	elasticsearch_install_set
	elasticsearch_install

}
