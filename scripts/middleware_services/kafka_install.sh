#!/bin/bash

kafka_env_load(){
	
	tmp_dir=/usr/local/src/kafka_tmp
	mkdir -p ${tmp_dir}
	soft_name=kafka
	program_version=('2.1' '2.2' '2.3')
	url='https://repo.huaweicloud.com/apache/kafka'
	select_version
	install_dir_set
	online_version

}

kafka_down(){
	down_url="${url}/${detail_version_number}/kafka_2.11-${detail_version_number}.tgz"
	online_down_file
	unpacking_file ${tmp_dir}/kafka_2.11-${detail_version_number}.tgz ${tmp_dir}

}

kafka_install_set(){
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/kafka/kafka-single.conf
		. ${workdir}/config/kafka/kafka-single.conf
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/kafka/kafka-cluster.conf
		. ${workdir}/config/kafka/kafka-cluster.conf
	fi
	

}

kafka_run_env_check(){
	###检测java环境
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
	###检测zookeeper可用
	zookeeper_ip1=`echo ${zookeeper_ip[0]} | awk -F : '{print$1}'`
	zookeeper_port1=`echo ${zookeeper_ip[0]} | awk -F : '{print$2}'`
	zookeeper_status=`exec 3<> /dev/tcp/${zookeeper_ip1}/${zookeeper_port1};echo "ruok" 1>&3;cat 0<&3`
	if [[ ${zookeeper_status} = 'imok' ]];then
		success_log "zookeeper运行环境已就绪"
	else
		error_log "zookeeper运行环境未就绪"
		exit 1
	fi
}

kafka_install(){

	if [[ ${deploy_mode} = '1' ]];then
		kafka_run_env_check
		kafka_down
		home_dir=${install_dir}/kafka
		mkdir -p ${home_dir}
		kafka_config
		cp -rp ${tar_dir}/* ${home_dir}
		add_kafka_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		#auto_ssh_keygen
		kafka_run_env_check
		kafka_down
		local i=0
		local k=0
		for now_host in ${host_ip[@]}
		do
			kafka_port=9092
			for ((j=0;j<${node_num[$k]};j++))
			do
				broker_id=$i
				let kafka_port=9092+$j
				kafka_config
				home_dir=${install_dir}/kafka-broker${broker_id}
				add_kafka_service
				info_log "正在向节点${now_host}分发kafka-broker${broker_id}安装程序和配置文件..."
				auto_input_keyword "
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				mkdir -p ${install_dir}/kafka-broker${broker_id}
				EOF
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/kafka-broker${broker_id}
				scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
				. /tmp/public.sh
				Type=simple
				ExecStart='${home_dir}/bin/kafka-server-start.sh'
				StartArgs='${home_dir}/config/server.properties'
				ExecStop='${home_dir}/bin/kafka-server-stop.sh'
				Environment='JAVA_HOME=${JAVA_HOME} KAFKA_HOME=${home_dir}'
				add_daemon_file ${home_dir}/kafka-broker${broker_id}.service
				add_system_service kafka-broker${broker_id} ${home_dir}/kafka-broker${broker_id}.service
				service_control kafka-broker${broker_id} restart
				rm -rf /tmp/public.sh
				EOF" "${passwd[$k]}"
				((i++))
			done
			((k++))
		done
		
	fi
}

kafka_config(){
	conf_dir=${tar_dir}/config
	bin_dir=${tar_dir}/bin
	if [[ ${deploy_mode} = '1' ]];then
		get_ip
		listeners_ip=${local_ip}
	else
		listeners_ip=${now_host}
	fi
	
	zookeeper_url="${zookeeper_ip[@]}"
	zookeeper_connect=$(echo ${zookeeper_url} | sed 's/ /,/g')
	[[ -n ${broker_id} ]] && sed -i "s/broker.id=.*/broker.id=${broker_id}/" ${conf_dir}/server.properties
	[[ -z ${kafka_port} ]] && kafka_port=9092
	[[ -z `grep ^port ${conf_dir}/server.properties` ]] && sed -i "/broker.id=.*/aport=${kafka_port}" ${conf_dir}/server.properties
	[[ -n `grep ^port ${conf_dir}/server.properties` ]] && sed -i "s/port=.*/port=${kafka_port}/" ${conf_dir}/server.properties
	[[ -z `grep ^listeners ${conf_dir}/server.properties` ]] && sed -i "s%#listeners=.*%listeners=PLAINTEXT://${listeners_ip}:${kafka_port}%" ${conf_dir}/server.properties
	[[ -n `grep ^listeners ${conf_dir}/server.properties` ]] && sed -i "s%listeners=.*%listeners=PLAINTEXT://${listeners_ip}:${kafka_port}%" ${conf_dir}/server.properties
	sed -i "s%log.dirs=.*%log.dirs=${kafka_data_dir}/broker${broker_id}%" ${conf_dir}/server.properties
	sed -i "s/zookeeper.connect=.*/zookeeper.connect=${zookeeper_connect}/" ${conf_dir}/server.properties
	sed -i "s/zookeeper.connection.timeout.ms=.*/zookeeper.connection.timeout.ms=12000/" ${conf_dir}/server.properties
	#堆内存配置
	[[ -n ${jvm_heap} ]] && sed -i "s/1G/${jvm_heap}/g" ${bin_dir}/kafka-server-start.sh

}

add_kafka_service(){
	if [[ ${deploy_mode} = '1' ]];then
		Type=simple
		ExecStart="${home_dir}/bin/kafka-server-start.sh"
		StartArgs="${home_dir}/config/server.properties"
		ExecStop="${home_dir}/bin/kafka-server-stop.sh"
		Environment="JAVA_HOME=${JAVA_HOME} KAFKA_HOME=${home_dir}"
		add_daemon_file ${home_dir}/kafka.service
		add_system_service kafka ${home_dir}/kafka.service
		service_control kafka restart
	fi

}

kafka_install_ctl(){

	kafka_env_load
	kafka_install_set
	kafka_install
	
}