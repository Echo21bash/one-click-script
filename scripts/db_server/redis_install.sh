#!/bin/bash

redis_env_load(){
	tmp_dir=/tmp/redis_tmp
	soft_name=redis
	program_version=('3.2' '4.0' '5.0')
	url="https://mirrors.huaweicloud.com/redis"
	select_version
	install_dir_set
	online_version

}

redis_down(){

	down_url="${url}/redis-${detail_version_number}.tar.gz"
	online_down_file
	unpack_file_name=${tmp_dir}/redis-${detail_version_number}.tar.gz
	unpack_dir=${tmp_dir}
	unpacking_file
}

redis_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置端口号' '6379' 'redis_port'
		input_option '请设置redis密码' 'passw0ord' 'redis_password'
		redis_password=${input_value}
		input_option '请设置数据目录' '/data/redis' 'redis_data_dir'
		redis_data_dir=${input_value}
	else
		output_option '请选择集群模式' '多主多从(集群模式) 一主多从(哨兵模式)' 'cluster_mode'
	fi
		
	if [[ ${cluster_mode} = '1' ]];then
		vi ${workdir}/config/redis/redis_cluster.conf
		. ${workdir}/config/redis/redis_cluster.conf

	fi

	if [[ ${cluster_mode} = '2' ]];then
		input_option '输入本机部署个数' '1' 'deploy_num'
		only_allow_numbers ${deploy_num}
		if [[ $? = 1 ]];then
			echo -e "${error} 输入错误请重新设置"
			redis_install_set
		fi
		
		node_type_set 
		
		if [[ ${node_type} = 'm' ]];then
			echo -e "${info} 这将第一个节点配置为主节点，其余节点为从节点。"
			input_option '输入起始端口号' '7001' 'redis_port'
			input_option '请设置redis密码' 'passw0ord' 'redis_password'
			redis_password=${input_value}
		elif [[ ${node_type} = 's' ]];then
			echo -e "${info} 这将所有节点都配置从节点，密码必须和主节点一样！"
			diy_echo "输入需要同步的主节点的信息" "$plain" "$info"
			input_option '请输入主节点ip地址' '192.168.1.1' 'mast_redis_ip'
			mast_redis_ip="$input_value"
			input_option '请输入主节点端口号' '6379' 'mast_redis_port'
			input_option '请输入主节点验证密码' 'password' 'mast_redis_passwd'
			mast_redis_passwd="$input_value"
			redis_password="$input_value"
			input_option '输入起始端口号' '7001' 'redis_port'
		fi
	fi

}

redis_install(){

	info_log "正在安装编译工具及库文件..."
	yum -y install make  gcc-c++
	if [ $? = '0' ];then
		info_log "编译工具及库文件安装成功."
	else
		error_log "编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	if [[ ${deploy_mode} = '2' && ${cluster_mode} = '1' && ${version_number} < '5.0' ]];then
		if [[ $(which ruby 2>/dev/null)  &&  $(ruby -v | grep -oE "[0-9]{1}\.[0-9]{1}\.[0-9]{1}") > '2.2.2' ]];then
			gem install redis
		else
			error_log "ruby未安装或者版本低于2.2.2"
			exit 1
		fi
	fi
	###编译redis
	make_home_dir=${tmp_dir}/redis
	cd ${tar_dir}
	make && cd ${tar_dir}/src && make PREFIX=${make_home_dir} install
	if [ $? = '0' ];then
		info_log "Redis编译完成"
	else
		error_log "Redis编译失败!" && exit
	fi

	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/redis
		mkdir -p ${home_dir} ${redis_data_dir}
		cp -rp ${make_home_dir}/* ${home_dir}
		redis_config
		add_redis_service
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
	elif [ ${deploy_mode} = '2' ];then
		auto_ssh_keygen
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			redis_port=${redis_start_port}
			for ((j=0;j<${node_num[$k]};j++))
			do
				service_id=$i
				let redis_port=${redis_start_port}+$j
				add_redis_server_list
				redis_config
				home_dir=${install_dir}/redis-node${service_id}				
				add_redis_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${install_dir}/redis-node${service_id}
				mkdir -p ${redis_data_dir}/node${service_id}
				"
				info_log "正在向节点${now_host}分发redis-node${service_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${make_home_dir}/* ${host_ip[$k]}:${install_dir}/redis-node${service_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{redis-node${i}.service,log_cut_redis-node${i}} ${host_ip[$k]}:${install_dir}/redis-node${service_id}
				
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${install_dir}/redis-node${service_id}/redis-node${i}.service /etc/systemd/system/redis-node${i}.service
				\cp ${install_dir}/redis-node${service_id}/log_cut_redis-node${i} /etc/logrotate.d/redis-node${i}
				systemctl daemon-reload
				"
				info_log "正在启动节点redis-node${service_id}..."
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				systemctl enable redis-node${service_id}
				systemctl restart redis-node${service_id}
				"
				((i++))
			done
			((k++))
		done
		redis_cluster_init
	fi
}

add_redis_server_list(){
	redis_service_list="${redis_service_list}${now_host}:${redis_port} "

}

redis_config(){
	#public config
	mkdir -p ${make_home_dir}/{etc,logs}
	conf_dir=${make_home_dir}/etc
	cp ${tar_dir}/redis.conf ${conf_dir}/redis.conf
	sed -i "s/^port .*/port ${redis_port}/" ${conf_dir}/redis.conf
	sed -i 's/^daemonize no/daemonize yes/' ${conf_dir}/redis.conf
	if [[ -n ${redis_password} ]];then
		sed -i "s/# requirepass foobared/requirepass ${redis_password}/" ${conf_dir}/redis.conf
	fi
	sed -i 's/# maxmemory <bytes>/maxmemory 100mb/' ${conf_dir}/redis.conf
	sed -i 's/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/' ${conf_dir}/redis.conf
	sed -i 's/appendonly no/appendonly yes/' ${conf_dir}/redis.conf
	
	if [[ ${deploy_mode} = '1' ]];then
		get_ip
		mkdir -p ${home_dir}/{logs,etc,data}
		cp -rp ${make_home_dir}/redis/* ${home_dir}
		cp ${conf_dir}/redis.conf ${home_dir}/etc/redis.conf
		sed -i "s/^bind.*/bind ${local_ip}/" ${home_dir}/etc/redis.conf
		sed -i "s#^pidfile .*#pidfile ${redis_data_dir}/redis-${redis_port}.pid#" ${home_dir}/etc/redis.conf
		sed -i "s#^logfile .*#logfile ${home_dir}/logs/redis.log#" ${home_dir}/redis.conf
		sed -i "s#^dir .*#dir ${redis_data_dir}#" ${conf_dir}/redis.conf
		add_log_cut ${home_dir}/log_cut_redis ${home_dir}/logs/redis.log
	fi
	
	if [[ ${deploy_mode} = '2' && ${cluster_mode} = '1' ]];then
		cp ${tar_dir}/src/redis-trib.rb ${make_home_dir}/bin/redis-trib.rb
		sed -i "s/^bind.*/bind ${now_host}/" ${conf_dir}/redis.conf
		sed -i "s#^pidfile .*#pidfile ${redis_data_dir}/node${service_id}/redis-${redis_port}.pid#" ${conf_dir}/redis.conf
		sed -i "s#^logfile .*#logfile ${install_dir}/redis-node${service_id}/logs/redis.log#" ${conf_dir}/redis.conf
		sed -i "s#^dir .*#dir ${redis_data_dir}/node${service_id}#" ${conf_dir}/redis.conf
		if [[ -n ${redis_password} ]];then
			sed -i "s/^# masterauth <master-password>/masterauth ${redis_password}/" ${conf_dir}/redis.conf
		fi
		sed -i "s/# cluster-enabled yes/cluster-enabled yes/" ${conf_dir}/redis.conf
		sed -i "s/# cluster-config-file nodes-6379.conf/cluster-config-file nodes-${redis_port}.conf/" ${conf_dir}/redis.conf
		sed -i "s/# cluster-node-timeout 15000/cluster-node-timeout 15000/" ${conf_dir}/redis.conf
		add_log_cut ${tmp_dir}/log_cut_redis-node${service_id} ${install_dir}/redis-node${service_id}/logs/redis.log
	fi
	
	if [[ ${deploy_mode} = '2' && ${cluster_mode} = '2' ]];then
		cp ${tar_dir}/sentinel.conf ${make_home_dir}/sentinel.conf
		
		sed -i "s/^bind.*/bind ${now_host}/" ${conf_dir}/redis.conf
		sed -i "s#^pidfile .*#pidfile ${redis_data_dir}/node${service_id}/redis-${redis_port}.pid#" ${conf_dir}/redis.conf
		sed -i "s#^logfile .*#logfile ${install_dir}/redis-node${service_id}/logs/redis.log#" ${conf_dir}/redis.conf
		if [[ -n ${redis_password} ]];then
			sed -i "s/^# masterauth <master-password>/masterauth ${redis_password}/" ${conf_dir}/redis.conf
		fi
		if [[ ${node_type} = 'M' && ${i} != '1' ]];then
			sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
		elif [[  ${node_type} = 'S' ]];then
			sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
		fi
		#哨兵配置文件
		sed -i "s/^# bind.*/bind ${now_host}/" ${conf_dir}/sentinel.conf
		sed -i "s/^port .*/port 2${redis_port}/" ${conf_dir}/sentinel.conf
		sed -i "s#^dir .*#dir ${redis_data_dir}\nlogfile ${install_dir}/redis-node${service_id}/logs/sentinel.log\npidfile ${install_dir}/redis-node${service_id}/redis_sentinel.pid\ndaemonize yes#" ${conf_dir}/sentinel.conf
		sed -i "s#^sentinel monitor mymaster 127.0.0.1 6379 2#sentinel monitor mymaster ${now_host} ${mast_redis_port} 2#" ${conf_dir}/sentinel.conf
		if [[ -n ${redis_password} ]];then
			sed -i 's!^# sentinel auth-pass mymaster.*!sentinel auth-pass mymaster '${redis_password}'!' ${conf_dir}/sentinel.conf
		fi
		add_log_cut ${tmp_dir}/log_cut_redis-node${service_id} ${install_dir}/redis-node${service_id}/logs/*.log
	fi

}

add_redis_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/redis-server ${home_dir}/etc/redis.conf"

	if [[ ${deploy_mode} = '1' ]];then
		conf_system_service ${home_dir}/redis.service
		add_system_service redis ${home_dir}/redis.service
	elif [[ ${deploy_mode} = '2' ]];then
		conf_system_service ${tmp_dir}/redis-node${service_id}.service
		service_control redis-node${service_id}.service
		if [[ ${cluster_mode} = '2' ]];then
			ExecStart="${home_dir}/bin/redis-sentinel ${home_dir}/etc/sentinel"
			conf_system_service ${tmp_dir}/redis-sentinel-node${service_id}.service
			add_system_service redis-sentinel-node${service_id} ${tmp_dir}/redis-sentinel-node${service_id}.service
		fi
	fi
}

redis_cluster_init(){
	###集群初始化
	if [[ ${version_number} < '5.0' ]];then
		ruby_redis_config=`find / -name client.rb | grep redis`
		sed -i "s/password:.*,/password: '${redis_password}',/" ${ruby_redis_config}
		redis_init=`expect <<-EOF
		set timeout -1
		spawn ssh ${host_ip[0]} -p ${ssh_port[0]} "${install_dir}/redis-node1/bin/redis-trib.rb create --replicas 1 ${redis_service_list}"
		expect {
			"*(type 'yes' to accept):*" { send "yes\r";exp_continue}
		}
		EOF`
	fi
	if [[ ${version_number} > '4.0' ]];then
		redis_init=`expect <<-EOF
		set timeout -1
		spawn ssh ${host_ip[0]} -p ${ssh_port[0]} "${install_dir}/redis-node1/bin/redis-cli -a ${redis_password} --cluster create ${redis_service_list} --cluster-replicas 1"
		expect {
			"*(type 'yes' to accept):*" { send "yes\r";exp_continue}
		}
		EOF`
	fi

	if [[ -z `echo $redis_init | grep -Eo  "\[ERR\].*"` ]];then
		success_log "redis集群初始化成功"
		info_log "redis连接地址:${redis_service_list}"
	else
		error_log "redis集群初始化失败"
	fi
}

redis_install_ctl(){
	redis_env_load
	redis_install_set
	redis_down
	redis_install
	clear_install
}