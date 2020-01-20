#!/bin/bash

mysql_install_set(){
	output_option '请选择mysql版本' 'mysql普通版 galera版(wsrep补丁)' 'branch'
	output_option '请选择安装模式' '单机单实例 单机多实例(mysqld_multi)' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请输入MySQL端口' '3306' 'mysql_port'
	else
		input_option '请输入MySQL起始端口' '3306' 'mysql_port'
		input_option '输入本机部署实例个数' '2' 'deploy_num'
	fi
	input_option '请输入MySQL数据目录' '/data/mysql' 'data_dir'
	data_dir=${input_value}
	input_option '请输入MySQL[root]账号初始密码' '123456' 'mysql_passwd'
	mysql_passwd=${input_value}

}

mysql_install(){
	#添加mysql用户
	groupadd mysql >/dev/null 2>&1
	useradd -M -s /sbin/nologin mysql -g mysql >/dev/null 2>&1
	mv ${tar_dir}/* ${home_dir}
	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum install -y perl-Module-Pluggable libaio autoconf boost-program-options
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
		
	if [[ ${deploy_mode} = '1' ]];then
		mysql_initialization
		mysql_standard_config
		mysql_config
		add_sys_env "MYSQL_HOME=${home_dir} PATH=\${MYSQL_HOME}/bin:\$PATH"
		add_mysql_service
		mysql_first_password_set
	else
		mysql_multi_config_a
		for ((i=1;i<=${deploy_num};i++))
		do
			mysql_initialization
			mysql_multi_config_b
			mysql_config
			mysql_port=$((${mysql_port}+1))
		done
		mysql_multi_config_c
		add_sys_env "MYSQL_HOME=${home_dir} PATH=\${MYSQL_HOME}/bin:\$PATH"
		add_mysql_service
		mysql_first_password_set
	fi
}

mysql_initialization(){
	mkdir -p ${data_dir}/mysql-${mysql_port}
	mysql_data_dir=${data_dir}/mysql-${mysql_port}
	
	chown -R mysql:mysql ${home_dir}
	chown -R mysql:mysql ${mysql_data_dir}

	if [[ ${version_number} < '5.7' ]];then
		${home_dir}/scripts/mysql_install_db --user=mysql --basedir=${home_dir} --datadir=${mysql_data_dir} >/dev/null 2>&1
	else
		${home_dir}/bin/mysqld --initialize-insecure --user=mysql --basedir=${home_dir} --datadir=${mysql_data_dir} >/dev/null 2>&1
	fi
	if [ $? = "0" ]; then
		diy_echo "初始化数据库完成..." "" "${info}"
		chown -R root:root ${home_dir}
		chown -R mysql:mysql ${mysql_data_dir}
	else 
		diy_echo "初始化数据库失败..." "${red}" "${error}"
		exit 1
	fi
}

mysql_standard_config(){
	cat ${workdir}/config/mysql_standard_config.cnf >${home_dir}/my.cnf
}

mysql_multi_config_a(){
	cat ${workdir}/config/mysql_multi_config_a.cnf >${home_dir}/my.cnf
}

mysql_multi_config_b(){
	cat ${workdir}/config/mysql_multi_config_b.cnf >>${home_dir}/my.cnf
}

mysql_multi_config_c(){
	cat ${workdir}/config/mysql_multi_config_c.cnf >>${home_dir}/my.cnf
}

mysql_config(){

	#通用配置
	sed -i "s#socket  = /usr/local/mysql/data#socket  = ${mysql_data_dir}#" ${home_dir}/my.cnf
	sed -i "s#basedir = /usr/local/mysql#basedir = ${home_dir}#" ${home_dir}/my.cnf
	sed -i "s#datadir = /usr/local/mysql/data#datadir = ${mysql_data_dir}#" ${home_dir}/my.cnf
	#版本区别配置
	if [[ ${version_number} > '5.6' ]];then
		sed -i "s/#log_timestamps = SYSTEM/log_timestamps = SYSTEM/" ${home_dir}/my.cnf
		sed -i "s/#innodb_temp_data_file_path = ibtmp1:64M:autoextend:max:5G/innodb_temp_data_file_path = ibtmp1:64M:autoextend:max:5G/" ${home_dir}/my.cnf
	fi
	#部署模式区别配置
	if [[ ${deploy_mode} = '1' ]];then
		sed -i "s#^port    = 3306#port    = ${mysql_port}#" ${home_dir}/my.cnf
	else
		sed -i "s#^[mysqld3306]#[mysqld${mysql_port}]#" ${home_dir}/my.cnf
		sed -i "s#^mysqld     = /usr/local/mysql/bin/mysqld#mysqld    = ${home_dir}/bin/mysqld#" ${home_dir}/my.cnf
		sed -i "s#^mysqladmin = /usr/local/mysql/bin/mysqladmin#mysqladmin = ${home_dir}/bin/mysqladmin#" ${home_dir}/my.cnf
	fi
}

add_mysql_service(){

	if [[ ${deploy_mode} = '1' ]];then
		User="mysql"
		ExecStart="${home_dir}/bin/mysqld_safe --defaults-file=${home_dir}/my.cnf"
		conf_system_service
		add_system_service mysqld ${home_dir}/init y
	elif [[ ${deploy_mode} = '2' ]];then
		if [[ ${os_release} > 6 ]];then
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf --log=/tmp/mysql_multi.log start %i"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop %i"
			conf_system_service
			add_system_service mysqld@ ${home_dir}/init y
		else
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf start \$2"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop \$2"
			conf_system_service
			add_system_service mysqld_multi ${home_dir}/init y
		fi
	fi

}

mysql_first_password_set(){
	sleep 5
	if [[ ${version_number} < '5.7' ]];then
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -e "use mysql;update user set password=PASSWORD("\'${mysql_passwd}\'") where user='root';\nflush privileges;"
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -p${mysql_passwd}<<-EOF
		delete from mysql.user where not (user='root');
		DELETE FROM mysql.user where user='';
		flush privileges;
		EOF
	else
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -e "use mysql;update user set authentication_string = password("\'${mysql_passwd}\'"), password_expired = 'N', password_last_changed = now() where user = 'root';\nflush privileges;"
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -p${mysql_passwd}<<-EOF
		delete from mysql.user where not (user='root');
		DELETE FROM mysql.user where user='';
		flush privileges;
		EOF
	fi
	if [[ $? = '0' ]];then
		diy_echo "设置密码成功..." "" "${info}"
	else
		diy_echo "设置密码失败..." "${red}" "${error}"
	fi
}

mysql_install_ctl(){
	install_version mysql
	install_selcet
	mysql_install_set
	install_dir_set 
	download_unzip 
	mysql_install
	clear_install
}

mongodb_install_set(){
	if [[ ${os_bit} = '32' ]];then
		diy_echo "该版本不支持32位系统" "${red}" "${error}"
		exit 1
	fi
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	input_option '请输入本机部署个数' '1' 'deploy_num'
	input_option '请输入起始端口号' '27017' 'mongodb_port'
	input_option '请输入数据存储路径' '/data' 'mongodb_data_dir'
	mongodb_data_dir=${input_value}
}

mongodb_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/etc
	mkdir -p ${mongodb_data_dir}
	mongodb_config
	add_mongodb_service
}

mongodb_config(){
	conf_dir=${home_dir}/etc
	cat >${conf_dir}/mongodb.conf<<-EOF
	#端口号
	port = 27017
	bind_ip=0.0.0.0
	#数据目录
	dbpath=
	#日志目录
	logpath=
	fork = true
	#日志输出方式
	logappend = true
	#开启认证
	#auth = true
	EOF
	sed -i "s#port.*#port = ${mongodb_port}#" ${conf_dir}/mongodb.conf
	sed -i "s#dbpath.*#dbpath = ${mongodb_data_dir}#" ${conf_dir}/mongodb.conf
	sed -i "s#logpath.*#logpath = ${home_dir}/logs/mongodb.log#" ${conf_dir}/mongodb.conf
	add_sys_env "PATH=\${home_dir}/bin:\$PATH"
	add_log_cut mongodb ${home_dir}/logs/mongodb.log
}

add_mongodb_service(){
	ExecStart="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	ExecStop="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	conf_system_service
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
	add_system_service mongodb ${home_dir}/mongodb_init
}

mongodb_inistall_ctl(){
	install_version mongodb
	install_selcet
	mongodb_install_set
	install_dir_set
	download_unzip
	mongodb_install
	clear_install
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
		diy_echo "如果大于5.0版本,添加集群命令示例 redis-cli --cluster create 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006 --cluster-replicas 1"
	elif [[ ${cluster_mode} = '2' ]];then
		diy_echo "现在Redis集群已经配置好了" "" "${info}"
	fi
}

redis_install_ctl(){
	install_version redis
	install_selcet
	redis_install_set
	install_dir_set redis
	download_unzip redis
	redis_install
	service_control redis
	clear_install
}

memcached_inistall_set(){

	output_option "请选择安装版本" "普通版 集成repcached补丁版" "branch"
	input_option "输入本机部署个数" "1" "deploy_num"
	input_option "输入起始memcached端口号" "11211" "memcached_port"

	if [[ ${branch} = '2' ]];then
		diy_echo "集成repcached补丁,该补丁并非官方发布,目前最新补丁兼容1.4.13" "${yellow}" "${warning}"
		input_option "输入memcached同步端口号" "11210" "syn_port"
	fi
}

memcached_install(){
	diy_echo "正在安装依赖库..." "" "${info}"
	yum -y install make  gcc-c++ libevent libevent-devel
	if [ $? = '0' ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi

	cd ${tar_dir}
	
	if [ ${branch} = '1' ];then
		./configure --prefix=${home_dir} && make && make install
	fi
	if [ ${branch} = '2' ];then
		repcached_url="http://mdounin.ru/files/repcached-2.3.1-1.4.13.patch.gz"
		wget ${repcached_url} && gzip -d repcached-2.3.1-1.4.13.patch.gz && patch -p1 -i ./repcached-2.3.1-1.4.13.patch
		./configure --prefix=${home_dir} --enable-replication && make && make install
	fi
	if [ $? = '0' ];then
		echo -e "${info} memcached编译完成."
	else
		echo -e "${error} memcached编译失败" && exit 1
	fi

	if [ ${deploy_num} = '1'  ];then
		memcached_config
		add_memcached_service
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
	if [[ ${deploy_num} > '1' ]];then
		mv ${home_dir} ${install_dir}/tmp
		for ((i=1;i<=${deploy_num};i++))
		do
			\cp -rp ${install_dir}/tmp ${install_dir}/memcached-node${i}
			home_dir=${install_dir}/memcached-node${i}
			memcached_config
			add_memcached_service
			memcached_port=$((${memcached_port}+1))
		done
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
		
}

memcached_config(){
	mkdir -p ${home_dir}/etc ${home_dir}/logs
	cat >${home_dir}/etc/memcached<<-EOF
	USER="root"
	PORT="11211"
	MAXCONN="1024"
	CACHESIZE="64"
	LOG="-vv >>$home_dir/logs/memcached.log 2>&1"
	OPTIONS=""
	EOF
	sed -i 's/PORT="11211"/PORT="'${memcached_port}'"/' ${home_dir}/etc/memcached
	if [[ ${branch} = '2' ]];then
		sed -i 's/OPTIONS="" /OPTIONS="-x 127.0.0.1 -X '${syn_port}'"/' ${home_dir}/etc/memcached
	fi

}

add_memcached_service(){

	EnvironmentFile="${home_dir}/etc/memcached"
	ExecStart="${home_dir}/bin/memcached -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$LOG \$OPTIONS"
	conf_system_service
	if [[ ${deploy_num} = '1' ]];then
		add_system_service memcached "${home_dir}/init"
	else
		add_system_service memcached-node${i} "${home_dir}/init"
	fi
}

memcached_inistall_ctl(){
	install_version memcached
	install_selcet
	memcached_inistall_set
	install_dir_set
	download_unzip
	memcached_install
	service_control
	clear_install
}