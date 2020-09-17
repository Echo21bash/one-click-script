#!/bin/bash

zookeeper_env_load(){
	
	tmp_dir=/tmp/zookeeper_tmp
	mkdir -p ${tmp_dir}
	soft_name=zookeeper
	program_version=('3.4' '3.5')
	url='http://mirrors.ustc.edu.cn/apache/zookeeper'
	down_url='${url}/zookeeper-${detail_version_number}/zookeeper-${detail_version_number}.tar.gz'

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
		mv ${tar_dir}/* ${home_dir}
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
	zookeeper_env_load
	zookeeper_install_set
	select_version
	install_dir_set
	online_version
	online_down_file
	unpacking_file
	zookeeper_install
	clear_install
}
