#!/bin/bash
rocketmq_env_load(){
	
	tmp_dir=/usr/local/src/rocketmq_tmp
	mkdir -p ${tmp_dir}
	soft_name=rocketmq
	program_version=('4')
	url='https://mirrors.huaweicloud.com/apache/rocketmq'
	select_version
	install_dir_set
	online_version

}

rocketmq_down(){

	down_url="${url}/${detail_version_number}/rocketmq-all-bin-${detail_version_number}.zip"
	online_down_file
	unpacking_file ${tmp_dir}/rocketmq-all-bin-${detail_version_number}.zip ${tmp_dir}

}


rocketmq_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '2' ]];then
	
		echo -e "${info} Rocket集群模式比较灵活，可以有多个主节点，每个主节点可有多个从节点，互为主从的broker名字必须相同"
		input_option '请输入部署rocketmq的总个数' '4' 'deploy_num_total'
		input_option '请输入部署broker个数(主节点个数)' '2' 'broker_num'

		if [[ ${broker_num} > ${deploy_num_total} ]];then
			diy_echo '部署个数有错误重新输入' '' "$error"
		fi
		
		input_option '请输入所有部署rocketmq的ip地址,默认第一个为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'rocketmq_ip'
		rocketmq_ip=(${input_value[@]})
		input_option '请输入每台机器部署rocketmq的个数,默认第一个为本机个数(多个使用空格分隔)' "2 2" 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}

	fi
	
	diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"
	input_option '请设置rocketmq-broker的起始端口号' '10911' 'rocketmq_broker_port'
	input_option '请设置rocketmq-namesrv的起始端口号' '9876' 'rocketmq_namesrv_port'
	echo -e "${info} press any key to continue"
	read

}

borker_name_set(){
	input_option '输入broker名字' 'broker-a' 'broker_name'
	broker_name=(${input_value[@]})
}

node_type_set(){

	input_option '输入节点类型(主M/从S)' 'M' 'node_type'
	node_type=(${input_value[@]})
	if [[ ${node_type} = 'M' || ${node_type} = 'm' ]];then
		node_type='m'
	elif [[ ${node_type} = 'S' || ${node_type} = 's' ]];then
		node_type='s'
	else
		echo -e "${error} 输入错误请重新设置"
		node_type_set
	fi
}

rocketmq_install(){ 

	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		rocketmq_namesrvaddr
		rocketmq_config
		add_rocketmq_service
	fi
		
	if [[ ${deploy_mode} = '2' ]];then
		rocketmq_namesrvaddr
		for ((i=1;i<=${deploy_num_local};i++))
		do
			borker_name_set
			node_type_set
			\cp -rp ${tar_dir} ${install_dir}/rocketmq-${broker_name}-${node_type}-node${i}
			home_dir=${install_dir}/rocketmq-${broker_name}-${node_type}-node${i}
			rocketmq_config
			add_rocketmq_service
			rocketmq_broker_port=$((${rocketmq_broker_port}+4))
			rocketmq_namesrv_port=$((${rocketmq_namesrv_port}+1))
		done
	fi

	
}

rocketmq_namesrvaddr(){
	local i
	local j
	j=0
	namesrvaddr=''
	#循环取ip,次数等于部署机器个数
	for ip in ${rocketmq_ip[@]}
	do
		#循环取每台机器部署个数
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				namesrvaddr=${namesrvaddr}${ip}:$(((${rocketmq_namesrv_port}+${i})))\;
			done	
		done
		j=$(((${j}+1)))
	done

}

rocketmq_config(){

	cat ${workdir}/config/rocketmq_namesrv.properties >${home_dir}/conf/namesrv.properties

	cat ${workdir}/config/rocketmq_broker.properties >${home_dir}/conf/broker.properties


	sed -i "s#rocketmqHome=#rocketmqHome=${home_dir}#" ${home_dir}/conf/namesrv.properties
	sed -i "s#kvConfigPath=#kvConfigPath=${home_dir}/data/namesrv/kvConfig.json#" ${home_dir}/conf/namesrv.properties
	sed -i "s#listenPort=9876#listenPort=${rocketmq_namesrv_port}#" ${home_dir}/conf/namesrv.properties
	
	sed -i "s#brokerName=broker-a#brokerName=${broker_name}#" ${home_dir}/conf/broker.properties
	[[ ${node_type} = 's' ]] && sed -i "s#brokerId=0#brokerId=1#" ${home_dir}/conf/broker.properties

	sed -i "s#namesrvAddr=127.0.0.1:9876#namesrvAddr=${namesrvaddr}#" ${home_dir}/conf/broker.properties
	sed -i "s#brokerIP1=#brokerIP1=$(hostname -I)#" ${home_dir}/conf/broker.properties
	sed -i "s#listenPort=10911#listenPort=${rocketmq_broker_port}#" ${home_dir}/conf/broker.properties
	sed -i "s#storePathRootDir=.*#storePathRootDir=${home_dir}/data/store#" ${home_dir}/conf/broker.properties
	sed -i "s#storePathCommitLog=.*#storePathCommitLog=${home_dir}/data/store/commitlog#" ${home_dir}/conf/broker.properties
	[[ ${node_type} = 's' ]] && sed -i "s#brokerRole=ASYNC_MASTER#brokerRole=SLAVE#" ${home_dir}/conf/broker.properties
	sed -i 's#${user.home}/logs/rocketmqlogs#'${home_dir}'/logs#g' ${home_dir}/conf/*.xml
	sed -i 's#-server -Xms4g -Xmx4g -Xmn2g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m#-server -Xms512m -Xmx512m -Xmn256m -XX:MetaspaceSize=96m -XX:MaxMetaspaceSize=256m#' ${home_dir}/bin/runserver.sh
	sed -i 's#-server -Xms8g -Xmx8g -Xmn4g#-server -Xms512m -Xmx512m -Xmn256m#' ${home_dir}/bin/runbroker.sh
}

add_rocketmq_service(){
	Type="simple"
	Environment="JAVA_HOME=$(echo ${JAVA_HOME})"

	if [[ ${deploy_mode} = '1' ]];then
		ExecStart="${home_dir}/bin/mqbroker -c ${home_dir}/conf/broker.properties"
		add_daemon_file
		add_system_service rocketmq-broker ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		add_daemon_file
		add_system_service rocketmq-namesrv ${home_dir}/init
	elif [[ ${deploy_mode} = '2' ]];then
		ExecStart="${home_dir}/bin/mqbroker -c ${home_dir}/conf/broker.properties"
		add_daemon_file
		add_system_service rocketmq-${broker_name}-${node_type}-node${i} ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		add_daemon_file
		add_system_service rocketmq-namesrv-${broker_name}-${node_type}-node${i} ${home_dir}/init
	fi
	
}

rocketmq_install_ctl(){
	rocketmq_env_load
	rocketmq_install_set
	rocketmq_down
	rocketmq_install
	
}
