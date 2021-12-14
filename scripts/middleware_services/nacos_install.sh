#!/bin/bash

nacos_env_load(){
	
	tmp_dir=/usr/local/src/nacos_tmp
	mkdir -p ${tmp_dir}
	soft_name=nacos
	program_version=('1' '2')
	url='https://github.com/alibaba/nacos'
	select_version
	install_dir_set
	online_version

}

nacos_down(){

	down_url="${url}/releases/download/${detail_version_number}/nacos-server-${detail_version_number}.tar.gz"
	down_file_rename=nacos-server-${detail_version_number}.tar.gz
	online_down_file
	unpacking_file ${tmp_dir}/nacos-server-${detail_version_number}.tar.gz ${tmp_dir}
}

nacos_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/nacos/nacos-single.conf
		. ${workdir}/config/nacos/nacos-single.conf
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/nacos/nacos-cluster.conf
		. ${workdir}/config/nacos/nacos-cluster.conf
	fi
}

nacos_run_env_check(){

	if [[ ${deploy_mode} = '1' ]];then
		java_status=`${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && echo 0 || echo 1`
		if [[ ${java_status} = 0 ]];then
			success_log "java运行环境已就绪"
		else
			error_log "java运行环境未就绪"
			exit 1
		fi
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local k=0
		for now_host in ${host_ip[@]}
		do
			java_status="`auto_input_keyword "ssh -Tq ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && javaok
			EOF" "${passwd[$k]}"`"
			if [[ ${java_status} =~ "javaok" ]];then
				success_log "主机${host_ip[$k]}java运行环境已就绪"
			else
				error_log "主机${host_ip[$k]}java运行环境未就绪"
				exit 1
			fi
			((k++))
		done
	fi
}

nacos_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		nacos_run_env_check
		nacos_down
		home_dir=${install_dir}/nacos
		mkdir -p ${install_dir}/nacos
		nacos_config
		cp -rp ${tar_dir}/* ${home_dir}
		add_nacos_service
		service_control nacos start
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		nacos_run_env_check
		nacos_down
		add_nacos_server_list
		
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			zk_port=2181
			for ((j=0;j<${node_num[$k]};j++))
			do
				service_id=$i
				let zk_port=2181+$j
				nacos_config
				home_dir=${install_dir}/nacos-node${service_id}				
				add_nacos_service
				
				info_log "正在向节点${now_host}分发nacos-node${service_id}安装程序和配置文件..."
				auto_input_keyword "
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				mkdir -p ${install_dir}/nacos-node${service_id}
				mkdir -p ${nacos_data_dir}/node${service_id}
				EOF
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/nacos-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{myid_node${service_id},log_cut_nacos-node${i}} ${host_ip[$k]}:${install_dir}/nacos-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				. /tmp/public.sh
				Type=forking
				ExecStart='${home_dir}/bin/zkServer.sh start'
				Environment='JAVA_HOME=${JAVA_HOME} ZOO_LOG_DIR=${home_dir}/logs'
				SuccessExitStatus="143"
				add_daemon_file ${home_dir}/nacos-node${i}.service
				add_system_service nacos-node${i} ${home_dir}/nacos-node${i}.service
				\cp ${install_dir}/nacos-node${service_id}/myid_node${service_id} ${nacos_data_dir}/node${service_id}/myid
				\cp ${install_dir}/nacos-node${service_id}/log_cut_nacos-node${i} /etc/logrotate.d/nacos-node${i}
				service_control nacos-node${i} restart
				#rm -rf /tmp/public.sh
				EOF" "${passwd[$k]}"
				((i++))
			done
			((k++))
		done
		sleep 10
	fi

}

add_nacos_server_list(){
	local i=1
	local k=0
	for now_host in ${host_ip[@]}
	do
		zk_heartbeat_port=2888
		zk_info_port=3888
		for ((j=0;j<${node_num[$k]};j++))
		do
			service_id=$i
			let zk_heartbeat_port=${zk_heartbeat_port}+$j
			let zk_info_port=${zk_info_port}+$j
			if [[ ${service_id} = '1' ]];then
				rm -rf ${tmp_dir}/zk_list
			fi
			echo "server.${service_id}=${host_ip[$k]}:${zk_heartbeat_port}:${zk_info_port}">>${tmp_dir}/zk_list
			((i++))
		done
		((k++))
	done

}

nacos_config(){


	###修改端口
	if [[ -n ${nacos_port} ]];then
		sed -i "s#server.port=.*#server.port=${nacos_port}#" ${home_dir}/conf/application.properties
	fi
	#add_log_cut ${home_dir}/nacos ${home_dir}/logs/*.out

}

add_nacos_service(){

	if [[ ${deploy_mode} = '1' ]];then
		WorkingDirectory="${home_dir}"
		Type="forking"
		Environment="JAVA_HOME=${JAVA_HOME}"
		StartArgs="-m standalone"
		ExecStart="${home_dir}/bin/startup.sh"
		SuccessExitStatus="143"
		add_daemon_file ${tmp_dir}/nacos.service
		add_system_service nacos ${tmp_dir}/nacos.service
	fi
}


nacos_status_check(){

	if [[ ${deploy_mode} = '1' ]];then
		nacos_status=`service_control nacos-node${i} is-active`
		if [[ ${nacos_status} =~ 'active' ]];then
			success_log "nacos启动完成"
		else
			error_log "nacos启动失败"
		fi
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do

			for ((j=0;j<${node_num[$k]};j++))
			do
				nacos_status=`auto_input_keyword "ssh -Tq ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				. /tmp/public.sh
				service_control nacos-node${i} is-active
				EOF" "${passwd[$k]}"`
				if [[ ${nacos_status} =~ 'active' ]];then
					success_log "nacos-node${i}启动完成"
				else
					error_log "nacos-node${i}启动失败"
				fi
				((i++))
			done
			((k++))
		done
	fi
}

nacos_install_ctl(){
	nacos_env_load
	nacos_install_set
	nacos_install
	nacos_status_check
	
}
