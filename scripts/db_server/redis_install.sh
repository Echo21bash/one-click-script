#!/bin/bash

redis_env_load(){
	tmp_dir=/tmp/redis_tmp
	soft_name=redis
	program_version=('3.2' '4.0' '5.0')
	url="https://mirrors.huaweicloud.com/redis"
	down_url='${url}/${detail_version_number}.tar.gz'
}

redis_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置端口号' '6379' 'redis_port'
		input_option '请设置redis密码' 'passw0ord' 'redis_password'
		redis_password=${input_value}
	else
		output_option '请选择集群模式' '多主多从(集群模式) 一主多从(哨兵模式)' 'cluster_mode'
	fi
		
	if [[ ${cluster_mode} = '1' ]];then
		input_option '输入本机部署个数' '2' 'deploy_num'
		only_allow_numbers ${deploy_num}
		if [[ $? = 1 ]];then
			echo -e "${error} 输入错误请重新设置"
			redis_install_set
		fi
		input_option '输入起始端口号' '7001' 'redis_port'
		input_option '请设置redis密码' 'passw0ord' 'redis_password'
		redis_password=${input_value}
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
	diy_echo '按任意键继续' '' "$info"
	read

}

redis_install(){

	echo -e "${info} 正在安装编译工具及库文件..."
	yum -y install make  gcc-c++
	if [ $? = '0' ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	if [[ ${deploy_mode} = '2' && ${cluster_mode} = '1' && ${version_number} < '5.0' ]];then
		if [[ $(which ruby 2>/dev/null)  &&  $(ruby -v | grep -oE "[0-9]{1}\.[0-9]{1}\.[0-9]{1}") > '2.2.2' ]];then
			gem install redis
		else
			diy_echo "ruby未安装或者版本低于2.2.2" "" "${error}"
			exit 1
		fi
	fi

	cd ${tar_dir}
	make && cd ${tar_dir}/src && make PREFIX=${home_dir} install
	if [ $? = '0' ];then
		echo -e "${info} Redis安装完成"
	else
		echo -e "${error} Redis编译失败!" && exit
	fi

	if [[ ${deploy_mode} = '1' ]];then
		redis_config
		add_redis_service
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
	elif [ ${deploy_mode} = '2' ];then
		if [[ ${cluster_mode} = '2' && ${node_type} = 'M' ]];then
			mast_redis_port=${redis_port}
		fi
		mv ${home_dir} ${install_dir}/tmp
		for ((i=1;i<=${deploy_num};i++))
		do
			\cp -rp ${install_dir}/tmp ${install_dir}/redis-${redis_port}
			home_dir=${install_dir}/redis-${redis_port}
			redis_config
			add_redis_service
			redis_port=$((${redis_port}+1))
		done
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
		redis_cluster_description
	fi
}

redis_config(){
	get_ip
	mkdir -p ${home_dir}/{logs,etc,data}
	conf_dir=${home_dir}/etc
	cp ${tar_dir}/redis.conf ${conf_dir}/redis.conf
	sed -i "s/^bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/redis.conf
	sed -i 's/^port 6379/port '${redis_port}'/' ${conf_dir}/redis.conf
	sed -i 's/^daemonize no/daemonize yes/' ${conf_dir}/redis.conf
	sed -i "s#^pidfile .*#pidfile ${home_dir}/data/redis.pid#" ${conf_dir}/redis.conf
	sed -i 's#^logfile ""#logfile "'${home_dir}'/logs/redis.log"#' ${conf_dir}/redis.conf
	sed -i 's#^dir ./#dir '${home_dir}'/data#' ${conf_dir}/redis.conf
	sed -i 's/# requirepass foobared/requirepass '${redis_password}'/' ${conf_dir}/redis.conf
	sed -i 's/# maxmemory <bytes>/maxmemory 100mb/' ${conf_dir}/redis.conf
	sed -i 's/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/' ${conf_dir}/redis.conf
	sed -i 's/appendonly no/appendonly yes/' ${conf_dir}/redis.conf
	
	if [ ${deploy_mode} = '1' ];then
		add_log_cut redis ${home_dir}/logs/*.log
	elif [ ${deploy_mode} = '2' ];then
		if [[ ${cluster_mode} = '1' ]];then
			mkdir -p ${install_dir}/bin
			cp ${tar_dir}/src/redis-trib.rb ${install_dir}/bin/redis-trib.rb
			sed -i 's/^# masterauth <master-password>/masterauth '${redis_password}'/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-enabled yes/cluster-enabled yes/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-config-file nodes-6379.conf/cluster-config-file nodes-'${redis_port}'.conf/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-node-timeout 15000/cluster-node-timeout 15000/' ${conf_dir}/redis.conf
		elif [[ ${cluster_mode} = '2' ]];then
			cp ${tar_dir}/sentinel.conf ${conf_dir}/sentinel.conf
			sed -i 's/^# masterauth <master-password>/masterauth '${redis_password}'/' ${conf_dir}/redis.conf
			if [[ ${node_type} = 'M' && ${i} != '1' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
			elif [[  ${node_type} = 'S' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
			fi
			#哨兵配置文件
			sed -i "s/^# bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/sentinel.conf
			sed -i "s/^port 26379/port 2${redis_port}/" ${conf_dir}/sentinel.conf
			sed -i "s#^dir /tmp#dir ${home_dir}/data\nlogfile ${home_dir}/log/sentinel.log\npidfile ${home_dir}/data/redis_sentinel.pid\ndaemonize yes#" ${conf_dir}/sentinel.conf
			sed -i "s#^sentinel monitor mymaster 127.0.0.1 6379 2#sentinel monitor mymaster ${local_ip} ${mast_redis_port} 2#" ${conf_dir}/sentinel.conf
			sed -i 's!^# sentinel auth-pass mymaster.*!sentinel auth-pass mymaster '${redis_password}'!' ${conf_dir}/sentinel.conf
		fi
		add_log_cut redis_${redis_port} ${home_dir}/logs/*.log
	fi

}

add_redis_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/redis-server ${home_dir}/etc/redis.conf"
	PIDFile="${home_dir}/data/redis.pid"
	conf_system_service
	if [[ ${deploy_mode} = '1' ]];then
		add_system_service redis ${home_dir}/init
	elif [[ ${deploy_mode} = '2' ]];then
		add_system_service redis-${redis_port} ${home_dir}/init
		if [[ ${cluster_mode} = '2' ]];then
			ExecStart="${home_dir}/bin/redis-sentinel ${home_dir}/etc/sentinel"
			PIDFile="${home_dir}/data/redis_sentinel.pid"
			conf_system_service
			add_system_service redis-sentinel-2${redis_port} ${home_dir}/init
		fi
	fi
}

redis_cluster_description(){
	if [[ ${cluster_mode} = '1' ]];then
		diy_echo "现在Redis集群已经配置好了" "" "${info}"
		diy_echo "如果小于5.0版本,添加集群命令示例 ${install_dir}/bin/redis-trib.rb create --replicas 1 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006,如果设置了集群密码还需要修改所使用ruby版本（本脚本默认使用ruby版本2.3.3）对应的client.rb文件（可通过find命令查找）,将password字段修改成对应的密码。"
		diy_echo "如果大于5.0版本,添加集群命令示例 redis-cli -a ${redis_password} --cluster create 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006 --cluster-replicas 1"
	elif [[ ${cluster_mode} = '2' ]];then
		diy_echo "现在Redis集群已经配置好了" "" "${info}"
	fi
}

redis_install_ctl(){
	redis_env_load
	redis_install_set
	select_version
	online_version
	online_down_file
	unpacking_file
	install_set
	redis_install
	clear_install
}