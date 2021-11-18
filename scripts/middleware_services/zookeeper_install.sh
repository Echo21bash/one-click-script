#!/bin/bash

zookeeper_env_load(){
	
	tmp_dir=/usr/local/src/zookeeper_tmp
	mkdir -p ${tmp_dir}
	soft_name=zookeeper
	program_version=('3.4' '3.5')
	url='https://repo.huaweicloud.com/apache/zookeeper'
	select_version
	install_dir_set
	online_version

}

zookeeper_down(){

	down_url="${url}/zookeeper-${detail_version_number}/zookeeper-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/zookeeper-${detail_version_number}.tar.gz ${tmp_dir}

}

zookeeper_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置zookeeper的客户端口号' '2181' 'zk_port'
		input_option '请设置zookeeper的数据存储目录' '/data/zookeeper_data' 'zookeeper_data_dir'
		zookeeper_data_dir=${input_value}
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/zookeeper/zookeeper.conf
		. ${workdir}/config/zookeeper/zookeeper.conf
	fi
}

zookeeper_run_env_check(){

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
			java_status=`auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && echo 0 || echo 1
			EOF" "${passwd[$k]}"`
			if [[ ${java_status} = 0 ]];then
				success_log "主机${host_ip[$k]}java运行环境已就绪"
			else
				error_log "主机${host_ip[$k]}java运行环境未就绪"
				exit 1
			fi
			((k++))
		done
	fi
}

zookeeper_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		zookeeper_run_env_check
		zookeeper_down
		home_dir=${install_dir}/zookeeper
		mkdir -p ${install_dir}/zookeeper
		zookeeper_config
		cp -rp ${tar_dir}/* ${home_dir}
		add_zookeeper_service
		service_control zookeeper start
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		#auto_ssh_keygen
		zookeeper_run_env_check
		zookeeper_down
		add_zookeeper_server_list
		
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			zk_port=2181
			for ((j=0;j<${node_num[$k]};j++))
			do
				service_id=$i
				let zk_port=2181+$j
				zookeeper_config
				home_dir=${install_dir}/zookeeper-node${service_id}				
				add_zookeeper_service
				
				info_log "正在向节点${now_host}分发zookeeper-node${service_id}安装程序和配置文件..."
				auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} \"mkdir -p ${install_dir}/zookeeper-node${service_id};mkdir -p ${zookeeper_data_dir}/node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/zookeeper-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{myid_node${service_id},log_cut_zookeeper-node${i}} ${host_ip[$k]}:${install_dir}/zookeeper-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
				. /tmp/public.sh
				Type="forking"
				ExecStart="${home_dir}/bin/zkServer.sh start"
				Environment="JAVA_HOME=${JAVA_HOME} ZOO_LOG_DIR=${home_dir}/logs"
				add_daemon_file ${home_dir}/zookeeper-node${i}.service
				add_system_service zookeeper ${home_dir}/zookeeper-node${i}.service
				\cp ${install_dir}/zookeeper-node${service_id}/myid_node${service_id} ${zookeeper_data_dir}/node${service_id}/myid
				\cp ${install_dir}/zookeeper-node${service_id}/log_cut_zookeeper-node${i} /etc/logrotate.d/zookeeper-node${i}
				service_control zookeeper-node${i} restart
				#rm -rf /tmp/public.sh
				EOF" "${passwd[$k]}"
				((i++))
			done
			((k++))
		done
		sleep 10
		zookeeper_cluster_check
	fi

}

add_zookeeper_server_list(){
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

zookeeper_config(){

	conf_dir=${tar_dir}/conf
	\cp ${conf_dir}/zoo_sample.cfg ${conf_dir}/zoo.cfg
	\cp ${workdir}/config/zookeeper/java.env ${conf_dir}
	if [[ -n ${jvm_heap} ]];then
		sed -i "s#512m#${jvm_heap}#g" ${conf_dir}/java.env
	fi
	sed -i "s#clientPort=.*#clientPort=${zk_port}#" ${conf_dir}/zoo.cfg
	if [[ ${deploy_mode} = '1' ]];then
		if [[ ! -d ${zookeeper_data_dir} ]];then
			mkdir -p ${zookeeper_data_dir}
		fi
		sed -i "s#dataDir=.*#dataDir=${zookeeper_data_dir}#" ${conf_dir}/zoo.cfg
		sed -i '/ZOOBIN="${BASH_SOURCE-$0}"/i ZOO_LOG_DIR='${install_dir}'/zookeeper/logs' ${tar_dir}/bin/zkServer.sh
		add_log_cut ${home_dir}/log_cut_zookeeper ${home_dir}/logs/zookeeper.out
		\cp ${home_dir}/log_cut_zookeeper /etc/rsyslog.d/
	else
		sed -i "s#dataDir=.*#dataDir=${zookeeper_data_dir}/node${service_id}#" ${conf_dir}/zoo.cfg
		if [[ -z `grep ^ZOO_LOG_DIR ${tar_dir}/bin/zkServer.sh` ]];then
			sed -i '/ZOOBIN="${BASH_SOURCE-$0}"/i ZOO_LOG_DIR='${install_dir}'/zookeeper-node'${service_id}'/logs' ${tar_dir}/bin/zkServer.sh
		fi
		if [[ -n `grep ^ZOO_LOG_DIR ${tar_dir}/bin/zkServer.sh` ]];then
			sed -i "s%ZOO_LOG_DIR=.*%ZOO_LOG_DIR=${install_dir}/zookeeper-node${service_id}/logs%" ${tar_dir}/bin/zkServer.sh
		fi
		cat ${tmp_dir}/zk_list >>${conf_dir}/zoo.cfg
		echo "${service_id}" > ${tmp_dir}/myid_node${service_id}
		add_log_cut ${tmp_dir}/log_cut_zookeeper-node${i} ${install_dir}/zookeeper-node${service_id}/logs/zookeeper.out
	fi

}

add_zookeeper_service(){
	if [[ ${deploy_mode} = '1' ]];then
		JAVA_HOME=${JAVA_HOME}
	fi
	
	Type="forking"
	ExecStart="${home_dir}/bin/zkServer.sh start"
	Environment="JAVA_HOME=${JAVA_HOME} ZOO_LOG_DIR=${home_dir}/logs"
	
	if [[ ${deploy_mode} = '1' ]];then
		add_daemon_file ${tmp_dir}/zookeeper.service
		add_system_service zookeeper ${tmp_dir}/zookeeper.service
	fi
}


zookeeper_cluster_check(){

	if [[ ${deploy_mode} = '2' ]];then
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do

			for ((j=0;j<${node_num[$k]};j++))
			do
				zookeeper_status=`auto_input_keyword "ssh -Tq ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				. /tmp/public.sh
				service_control zookeeper-node${i} is-active
				EOF" "${passwd[$k]"`
				if [[ ${zookeeper_status} = 'active' ]];then
					success_log "zookeeper-node${i}启动完成"
				else
					error_log "zookeeper-node${i}启动失败"
				fi
				((i++))
			done
			((k++))
		done
	fi
}

zookeeper_install_ctl(){
	zookeeper_env_load
	zookeeper_install_set
	zookeeper_install
	
}
