#!/bin/bash

activemq_install_set(){
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '2' ]];then
		output_option '请选择集群模式' 'Master-slave(高可用HA) Broker-clusters(负载均衡SLB) 混合模式' 'cluster_mode'
		if [[ ${cluster_mode} = '1' ]];then
			diy_echo '目前是基于共享文件的方式高可用方案' '' "$info"
			input_option '请输入共享文件夹目录' '/data/activemq' 'shared_dir'
			shared_dir=${input_value}
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
		
		if [[ ${cluster_mode} = '2' ]];then
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
		
		if [[ ${cluster_mode} = '3' ]];then
			input_option '请输入部署broker个数' '2' 'broker_num'
			input_option '请输入共享文件夹目录' '/data/activemq' 'shared_dir'
			shared_dir=${input_value}
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
	fi
	input_option '请设置连接activemq的起始端口号' '61616' 'activemq_conn_port'
	input_option '请设置管理activemq的起始端口号' '8161' 'activemq_mana_port'
	input_option '请设置连接activemq的用户名' 'system' 'activemq_username'
	activemq_username=${input_value}
	input_option '请设置连接activemq的密码' 'manager' 'activemq_userpasswd'
	activemq_userpasswd=${input_value}
	echo -e "${info} press any key to continue"
	read
	
}

activemq_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		activemq_config
		add_activemq_service
	fi
	if [[ ${deploy_mode} = '2' ]];then

		activemq_conn_port_default=${activemq_conn_port}
		activemq_mana_port_default=${activemq_mana_port}
		activemq_networkconn_port_default=${activemq_conn_port}

		for ((i=1;i<=${deploy_num};i++))
		do

			if [[ ${cluster_mode} = '1' || ${cluster_mode} = '2' ]];then
				\cp -rp ${tar_dir} ${install_dir}/activemq-node${i}
				home_dir=${install_dir}/activemq-node${i}
				activemq_config
				add_activemq_service
				activemq_conn_port=$((${activemq_conn_port}+1))
				activemq_mana_port=$((${activemq_mana_port}+1))
			fi
			
			if [[ ${cluster_mode} = '3' ]];then	

				#平均数
				average_value=$(((${deploy_num}/${broker_num})))
				#加权系数[0-(broker_num)]之间做为broker号
				weight_factor=$(((${i} % ${broker_num})))
				
				activemq_conn_port=${activemq_conn_port_default}
				activemq_mana_port=${activemq_mana_port_default}
				activemq_networkconn_port=${activemq_networkconn_port_default}
					
				activemq_conn_port=$((${activemq_conn_port}+${weight_factor}))
				activemq_mana_port=$((${activemq_mana_port}+${weight_factor}))
				#配置broker连接端口目前配置为环网连接
				if (( ${weight_factor} == $(((${broker_num} - 1))) ));then
					activemq_networkconn_port=${activemq_networkconn_port_default}
				else
					activemq_networkconn_port=$(((${activemq_networkconn_port_default}+${weight_factor}+1)))
				fi
					
				\cp -rp ${tar_dir} ${install_dir}/activemq-broker${weight_factor}-node${i}
				home_dir=${install_dir}/activemq-broker${weight_factor}-node${i}
				activemq_config
				add_activemq_service
			fi
		done
	fi

}

activemq_config(){

	cat > /tmp/activemq.xml.tmp << 'EOF'
        <plugins> 
           <simpleAuthenticationPlugin> 
                 <users> 
                      <authenticationUser username="${activemq.username}" password="${activemq.password}" groups="users,admins"/> 
                 </users> 
           </simpleAuthenticationPlugin> 
        </plugins>
EOF
	
	cat > /tmp/activemq.xml.networkConnector.tmp << EOF
				<networkConnectors>
						<networkConnector uri="static:(tcp://0.0.0.0:61616)" duplex="true" userName="${activemq_username}" password="${activemq_userpasswd}"/>
				</networkConnectors>	
EOF


	if [[ ${deploy_mode} = '1' ]];then
		#插入文本内容
		sed -i '/<\/persistenceAdapter>/r /tmp/activemq.xml.tmp' ${home_dir}/conf/activemq.xml
		#注释无用的消息协议只开启tcp
		sed -i 's#<transportConnector name#<!-- <transportConnector name#' ${home_dir}/conf/activemq.xml
		sed -i 's#maxFrameSize=104857600"/>#maxFrameSize=104857600"/> -->#' ${home_dir}/conf/activemq.xml
		sed -i 's#<!-- <  name="openwire".*maxFrameSize=104857600"/> -->#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600"/>#' ${home_dir}/conf/activemq.xml
		#配置链接用户密码
		sed -i 's#activemq.username=system#activemq.username='${activemq_username}'#' ${home_dir}/conf/credentials.properties
		sed -i 's#activemq.password=manager#activemq.password='${activemq_userpasswd}'#' ${home_dir}/conf/credentials.properties
	elif [[ ${deploy_mode} = '2' ]];then
		
			#插入文本内容
			sed -i '/<\/persistenceAdapter>/r /tmp/activemq.xml.tmp' ${home_dir}/conf/activemq.xml
			#注释无用的消息协议只开启tcp
			sed -i 's#<transportConnector name#<!-- <transportConnector name#' ${home_dir}/conf/activemq.xml
			sed -i 's#maxFrameSize=104857600"/>#maxFrameSize=104857600"/> -->#' ${home_dir}/conf/activemq.xml
			sed -i 's#<!-- <transportConnector name="openwire".*maxFrameSize=104857600"/> -->#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600"/>#' ${home_dir}/conf/activemq.xml
			#配置链接用户密码
			sed -i 's#activemq.username=system#activemq.username='${activemq_username}'#' ${home_dir}/conf/credentials.properties
			sed -i 's#activemq.password=manager#activemq.password='${activemq_userpasswd}'#' ${home_dir}/conf/credentials.properties

		if [[ ${cluster_mode} = '1' ]];then
			sed -i 's#<kahaDB directory="${activemq.data}/kahadb"/>#<kahaDB directory="'${shared_dir}'"/>#' ${home_dir}/conf/activemq.xml

		elif [[ ${cluster_mode} = '2' ]];then
			sed -i 's#brokerName="localhost"#brokerName="broker'${i}'"#' ${home_dir}/conf/activemq.xml
			sed -i '/<\/plugins>/r /tmp/activemq.xml.networkConnector.tmp' ${home_dir}/conf/activemq.xml
			sed -i 's#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616#<transportConnector name="openwire" uri="tcp://0.0.0.0:'${activemq_conn_port}'#' ${home_dir}/conf/activemq.xml
			sed -i 's#<property name="port" value="8161"/>#<property name="port" value="'${activemq_mana_port}'"/>#' ${home_dir}/conf/jetty.xml
		elif [[ ${cluster_mode} = '3' ]];then
			sed -i 's#brokerName="localhost"#brokerName="broker'${weight_factor}'"#' ${home_dir}/conf/activemq.xml
			sed -i 's#<kahaDB directory="${activemq.data}/kahadb"/>#<kahaDB directory="'${shared_dir}'/broker'${weight_factor}'"/>#' ${home_dir}/conf/activemq.xml
			sed -i '/<\/plugins>/r /tmp/activemq.xml.networkConnector.tmp' ${home_dir}/conf/activemq.xml
			sed -i 's#<networkConnector uri="static:(tcp://0.0.0.0:61616)#<networkConnector uri="static:(tcp://0.0.0.0:'${activemq_networkconn_port}')#' ${home_dir}/conf/activemq.xml
			sed -i 's#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616#<transportConnector name="openwire" uri="tcp://0.0.0.0:'${activemq_conn_port}'#' ${home_dir}/conf/activemq.xml
			sed -i 's#<property name="port" value="8161"/>#<property name="port" value="'${activemq_mana_port}'"/>#' ${home_dir}/conf/jetty.xml
		fi
	fi
}

add_activemq_service(){

	Type="forking"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	ExecStart="${home_dir}/bin/activemq start"
	ExecStop="${home_dir}/bin/activemq stop"
	conf_system_service
	if [[ ${deploy_mode} = '1' ]];then
		add_system_service activemq ${home_dir}/init
	fi
	if [[ ${deploy_mode} = '2' ]];then
		if [[ ${cluster_mode} = '1' ]];then		
			add_system_service activemq-node${i} ${home_dir}/init
		fi
		if [[ ${cluster_mode} = '2' ]];then	
			add_system_service activemq-broker${i}-node${i} ${home_dir}/init
		fi
		if [[ ${cluster_mode} = '3' ]];then
			add_system_service activemq-broker${weight_factor}-node${i} ${home_dir}/init
		fi
	fi

}

activemq_install_ctl(){
	install_version activemq
	install_selcet
	activemq_install_set
	install_dir_set
	download_unzip
	activemq_install
	clear_install
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

	cat >${home_dir}/conf/namesrv.properties<<-EOF
	rocketmqHome=
	kvConfigPath=
	listenPort=9876
	EOF
	cat >${home_dir}/conf/broker.properties<<-EOF
	#所属集群名字
	brokerClusterName=rocketmq-cluster
	#broker名字，注意此处不同的配置文件填写的不一样
	brokerName=broker-a
	#0 表示 Master，>0 表示 Slave
	brokerId=0
	#nameServer地址，分号分割
	namesrvAddr=127.0.0.1:9876
	#在发送消息时，自动创建服务器不存在的topic，默认创建的队列数
	defaultTopicQueueNums=4
	#是否允许 Broker 自动创建Topic，建议线下开启，线上关闭
	autoCreateTopicEnable=true
	#是否允许 Broker 自动创建订阅组，建议线下开启，线上关闭
	autoCreateSubscriptionGroup=true
	#Broker 对外服务的监听端口
	brokerIP1=
	listenPort=10911
	#删除文件时间点，默认凌晨 4点
	deleteWhen=04
	#文件保留时间，默认 48 小时
	fileReservedTime=120
	#commitLog每个文件的大小默认1G
	mapedFileSizeCommitLog=1073741824
	#ConsumeQueue每个文件默认存30W条，根据业务情况调整
	mapedFileSizeConsumeQueue=300000
	#destroyMapedFileIntervalForcibly=120000
	#redeleteHangedFileInterval=120000
	#检测物理文件磁盘空间
	diskMaxUsedSpaceRatio=88
	#存储路径
	storePathRootDir=/laihui/base-app/roketmq-cluster/rocketmq-M1/data/store
	#commitLog 存储路径
	storePathCommitLog=/laihui/base-app/roketmq-cluster/rocketmq-M1/data/store/commitlog
	#限制的消息大小
	#maxMessageSize=65536
	#flushCommitLogLeastPages=4
	#flushConsumeQueueLeastPages=2
	#flushCommitLogThoroughInterval=10000
	#flushConsumeQueueThoroughInterval=60000
	#Broker 的角色
	#- ASYNC_MASTER 异步复制Master
	#- SYNC_MASTER 同步双写Master
	#- SLAVE
	brokerRole=ASYNC_MASTER
	#刷盘方式
	#- ASYNC_FLUSH 异步刷盘
	#- SYNC_FLUSH 同步刷盘
	flushDiskType=ASYNC_FLUSH
	#checkTransactionMessageEnable=false
	#发消息线程池数量
	#sendMessageThreadPoolNums=128
	#发送消息是否使用可重入锁
	#useReentrantLockWhenPutMessage:true
	#拉消息线程池数量
	#pullMessageThreadPoolNums=128
	EOF

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
		conf_system_service
		add_system_service rocketmq-broker ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		conf_system_service
		add_system_service rocketmq-namesrv ${home_dir}/init
	elif [[ ${deploy_mode} = '2' ]];then
		ExecStart="${home_dir}/bin/mqbroker -c ${home_dir}/conf/broker.properties"
		conf_system_service
		add_system_service rocketmq-${broker_name}-${node_type}-node${i} ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		conf_system_service
		add_system_service rocketmq-namesrv-${broker_name}-${node_type}-node${i} ${home_dir}/init
	fi
	
}

rocketmq_install_ctl(){
	install_version rocketmq
	install_selcet
	rocketmq_install_set
	install_dir_set
	download_unzip
	rocketmq_install
	clear_install
}

zookeeper_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置zookeeper的客户端口号' '2181' 'zookeeper_connection_port'
	elif [[ ${deploy_mode} = '2' ]];then
		input_option "请输入部署总个数($(diy_echo 必须是奇数 $red))" '3' 'deploy_num_total'
		input_option '请输入所有部署zookeeper的机器的ip地址,第一个必须为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'zookeeper_ip'
		zookeeper_ip=(${input_value[@]})
		input_option '请输入每台机器部署zookeeper的个数,第一个必须为本机部署个数(多个使用空格分隔)' '2 1' 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}
		diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"

		input_option '请设置zookeeper的客户端口号' '2181' 'zookeeper_connection_port'
		input_option '请设置zookeeper的心跳端口号' '2888' 'zookeeper_heartbeat_port'
		input_option '请设置zookeeper的信息端口号' '3888' 'zookeeper_info_port'
		diy_echo "部署Zookeeper的机器的ip是$(diy_echo ${zookeeper_ip} $red)" "$plain" "$info"
		diy_echo "每台机器部署Zookeeper的个数是$(diy_echo ${zookeeper_num} $red)" "$plain" "$info"
		diy_echo "zookeeper的连接端口号是$(diy_echo ${zookeeper_connection_port} $red)" "$plain" "$info"
		diy_echo "zookeeper的心跳端口号是$(diy_echo ${zookeeper_heartbeat_port} $red)" "$plain" "$info"
		diy_echo "zookeeper的信息端口号是$(diy_echo ${zookeeper_info_port} $red)" "$plain" "$info"
		diy_echo "press any key to continue" "$plain" "$info"
		read
	fi
	
}

zookeeper_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		zookeeper_config
		add_zookeeper_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		add_zookeeper_server_list
		for ((i=1;i<=${deploy_num_local};i++))
		do
			\cp -rp ${tar_dir} ${install_dir}/zookeeper-node${i}
			home_dir=${install_dir}/zookeeper-node${i}
			zookeeper_config
			add_zookeeper_service
			zookeeper_connection_port=$((${zookeeper_connection_port}+1))
			zookeeper_heartbeat_port=$((${zookeeper_heartbeat_port}+1))
			zookeeper_info_port=$((${zookeeper_info_port}+1))
		done
	fi

}

add_zookeeper_server_list(){

	[[ -f /tmp/zoo.cfg ]] && rm -rf /tmp/zoo.cfg
	local i
	local j
	j=0
	serverid='1'
	#循环取ip,次数等于部署机器个数
	for ip in ${zookeeper_ip[@]}
	do
		#循环取每台机器部署个数
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				echo "server.$(((serverid++)))=${zookeeper_ip[$j]}:$(((zookeeper_heartbeat_port+$i))):$(((zookeeper_info_port+$i)))">>/tmp/zoo.cfg
			done	
		done
		j=$(((${j}+1)))
	done

}

zookeeper_config(){
	mkdir -p ${home_dir}/{logs,data}
	conf_dir=${home_dir}/conf
	cp ${conf_dir}/zoo_sample.cfg ${conf_dir}/zoo.cfg

	cat > ${conf_dir}/java.env <<-'EOF'
	#!/bin/sh
	export PATH
	# heap size MUST be modified according to cluster environment
	export JVMFLAGS="-Xms512m -Xmx512m -Xmn128m $JVMFLAGS"
	EOF

	sed -i "s#dataDir=/tmp/zookeeper#dataDir=${home_dir}/data#" ${conf_dir}/zoo.cfg
	sed -i "s#clientPort=.*#clientPort=${zookeeper_connection_port}#" ${conf_dir}/zoo.cfg
	sed -i '/ZOOBIN="${BASH_SOURCE-$0}"/i ZOO_LOG_DIR='${home_dir}'/logs' ${home_dir}/bin/zkServer.sh
	if [[ ${deploy_mode} = '2' ]];then
		cat /tmp/zoo.cfg >>${conf_dir}/zoo.cfg
		myid=$(cat /tmp/zoo.cfg | grep -E "${zookeeper_ip[0]}:${zookeeper_heartbeat_port}:${zookeeper_info_port}" | grep -Eo "server\.[0-9]{1,2}" | grep -oE "[0-9]{1,2}")
		cat > ${home_dir}/data/myid <<-EOF
		${myid}
		EOF
		add_log_cut zookeeper-node${i} ${home_dir}/logs/zookeeper.out
	else
		add_log_cut zookeeper ${home_dir}/logs/zookeeper.out
	fi
}

add_zookeeper_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/zkServer.sh start"
	Environment="JAVA_HOME=$(echo $JAVA_HOME) ZOO_LOG_DIR=${home_dir}/logs"
	conf_system_service 

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service zookeeper ${home_dir}/init
	else
		add_system_service zookeeper-node${i} ${home_dir}/init
	fi
}

zookeeper_install_ctl(){
	install_version zookeeper
	install_selcet
	zookeeper_install_set
	install_dir_set
	download_unzip
	zookeeper_install
	clear_install
}

kafka_install_set(){
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置kafka的端口号' '9092' 'kafka_port'
	elif [[ ${deploy_mode} = '2' ]];then
		input_option '请输入本机部署个数' '1' 'deploy_num_local'
		input_option '请设置kafka的起始端口号' '9092' 'kafka_port'
		diy_echo "集群内broker.id不能重复" "${yellow}" "${info}"
		input_option '请设置kafka的broker id' '0' 'kafka_id'
	fi
	input_option '请设置kafka数据目录' '/data/kafka' 'kafka_data_dir'
	diy_echo "此处建议使用单独zookeeper服务" "${yellow}" "${info}"
	input_option '请设置kafka连接的zookeeper地址池' '192.168.1.2:2181 192.168.1.3:2181 192.168.1.4:2181' 'zookeeper_ip'
	zookeeper_ip=(${input_value[@]})
}

kafka_install(){

	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		kafka_config
		add_kafka_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		
		for ((i=1;i<=${deploy_num_local};i++))
		do
			cp -rp ${tar_dir} ${install_dir}/kafka-node${i}
			home_dir=${install_dir}/kafka-node${i}
			kafka_config
			add_kafka_service
			kafka_port=$((${kafka_port}+1))
		done
	fi
}

kafka_config(){
	mkdir -p ${home_dir}/{logs,data}
	conf_dir=${home_dir}/config
	[[ -n ${kafka_id} ]] && sed -i "s/broker.id=0/broker.id=${kafka_id}/" ${conf_dir}/server.properties
	sed -i "/broker.id=.*/aport=${kafka_port}" ${conf_dir}/server.properties
	sed -i "s/log.dirs=.*/log.dirs=${kafka_data_dir}/${kafka_port}" ${conf_dir}/server.properties
	zookeeper_ip="${zookeeper_ip[@]}"
	zookeeper_connect=$(echo ${zookeeper_ip} | sed 's/ /,/g')
	sed -i "s/zookeeper.connect=localhost:2181/zookeeper.connect=${zookeeper_connect}/" ${conf_dir}/server.properties
}

add_kafka_service(){
	Type=simple
	ExecStart="${home_dir}/bin/kafka-server-start.sh ${home_dir}/config/server.properties"
	ExecStop="${home_dir}/bin/kafka-server-stop.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME) KAFKA_HOME=${home_dir}"
	conf_system_service 

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service kafka ${home_dir}/init
	else
		add_system_service kafka-node${i} ${home_dir}/init
	fi
}

kafka_install_ctl(){
	install_version kafka
	install_selcet
	kafka_install_set
	install_dir_set
	download_unzip
	kafka_install
	clear_install
}