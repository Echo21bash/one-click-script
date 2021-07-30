#!/bin/bash
kafka_env_load(){
	
	tmp_dir=/tmp/kafka_tmp
	mkdir -p ${tmp_dir}
	soft_name=kafka
	program_version=('2.1' '2.2' '2.3')
	url='https://mirrors.huaweicloud.com/apache/kafka'
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
		input_option '请设置kafka的端口号' '9092' 'kafka_port'
		input_option '请设置kafka数据目录' '/data/kafka' 'kafka_data_dir'
		kafka_data_dir=${input_value}
		diy_echo "此处建议使用单独zookeeper服务" "${yellow}" "${info}"
		input_option '请设置kafka连接的zookeeper地址池' '192.168.1.2:2181 192.168.1.3:2181 192.168.1.4:2181' 'zookeeper_ip'
		zookeeper_ip=(${input_value[@]})
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/kafka/kafka.conf
		. ${workdir}/config/kafka/kafka.conf
	fi
	

}

kafka_install(){

	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/kafka
		mkdir -p ${home_dir}
		kafka_config
		cp -rp ${tar_dir}/* ${home_dir}
		add_kafka_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
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
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${install_dir}/kafka-broker${broker_id}
				"
				info_log "正在向节点${now_host}分发kafka-broker${broker_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/kafka-broker${broker_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/kafka-broker${broker_id} ${host_ip[$k]}:${install_dir}/kafka-broker${broker_id}
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${install_dir}/kafka-broker${broker_id}/kafka-broker${broker_id} /etc/systemd/system/kafka-broker${broker_id}.service
				systemctl daemon-reload
				"
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
	
	zookeeper_ip="${zookeeper_ip[@]}"
	zookeeper_connect=$(echo ${zookeeper_ip} | sed 's/ /,/g')
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
		JAVA_HOME=${JAVA_HOME}
	else
		JAVA_HOME=`ssh ${host_ip[$k]} -p ${ssh_port[$k]} 'echo $JAVA_HOME'`
	fi
	
	if [[ -z ${JAVA_HOME} ]];then
		warning_log "主机${host_ip[$k]}没有正确配置JAVA_HOME变量"
	fi
	Type=simple
	ExecStart="${home_dir}/bin/kafka-server-start.sh ${home_dir}/config/server.properties"
	ExecStop="${home_dir}/bin/kafka-server-stop.sh"
	Environment="JAVA_HOME=${JAVA_HOME} KAFKA_HOME=${home_dir}"
	if [[ ${deploy_mode} = '1' ]];then
		conf_system_service ${home_dir}/kafka.service
		add_system_service kafka ${home_dir}/kafka.service
	else
		conf_system_service ${tmp_dir}/kafka-broker${broker_id}
	fi

}

kafka_install_ctl(){

	kafka_env_load
	kafka_install_set
	kafka_down
	kafka_install
	
}