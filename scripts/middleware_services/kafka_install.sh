#!/bin/bash
kafka_env_load(){
	
	tmp_dir=/tmp/kafka_tmp
	mkdir -p ${tmp_dir}
	soft_name=kafka
	program_version=('2.1' '2.2' '2.3')
	url='https://mirrors.huaweicloud.com/apache/kafka'
	down_url='${url}/${detail_version_number}/kafka_2.11-${detail_version_number}.tgz'

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
		cp -rp ${tar_dir}/* ${home_dir}
		kafka_config
		add_kafka_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
		home_dir=${tar_dir}
		
		local i=0
		local k=0
		for host in ${host_ip[@]}
		do
			for ((j=0;i<${node_num};j++))
			do
				broker_id=$i
				kafka_config
				home_dir=${install_dir}/kafka-broker${broker_id}
				add_kafka_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${install_dir}/kafka-broker${broker_id}
				"
				scp -r ${tar_dir}/* ${host_ip[$i]}/${install_dir}/kafka-broker${broker_id}
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${install_dir}/kafka-broker${broker_id}/kafka-broker${broker_id} /etc/systemd/system/kafka-broker${broker_id}
				systemctl daemon-reload
				"
				((i++))
			done
			((k++))
		done
		
	fi
}

kafka_config(){
	conf_dir=${home_dir}/config
	zookeeper_ip="${zookeeper_ip[@]}"
	zookeeper_connect=$(echo ${zookeeper_ip} | sed 's/ /,/g')
	[[ -n ${kafka_id} ]] && sed -i "s/broker.id=0/broker.id=${kafka_id}/" ${conf_dir}/server.properties
	sed -i "/broker.id=.*/aport=${kafka_port}" ${conf_dir}/server.properties
	sed -i "s%log.dirs=.*%log.dirs=${kafka_data_dir}%" ${conf_dir}/server.properties
	sed -i "s/zookeeper.connect=localhost:2181/zookeeper.connect=${zookeeper_connect}/" ${conf_dir}/server.properties
}

add_kafka_service(){
	if [[ ${deploy_mode} = '2' ]];then
		init_file=kafka-broker${broker_id}
		init_dir=${tmp_dir}
	fi
	Type=simple
	ExecStart="${home_dir}/bin/kafka-server-start.sh ${home_dir}/config/server.properties"
	ExecStop="${home_dir}/bin/kafka-server-stop.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME) KAFKA_HOME=${home_dir}"
	conf_system_service

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service kafka ${home_dir}/init
	fi
}

kafka_install_ctl(){

	kafka_env_load
	select_version
	kafka_install_set
	install_dir_set
	online_version
	online_down_file
	unpacking_file
	kafka_install
	clear_install
}