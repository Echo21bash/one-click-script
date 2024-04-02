#!/bin/bash

mysql_env_load(){
	tmp_dir=/usr/local/src/mysql_tmp
	soft_name=mysql
	program_version=('5.5' '5.6' '5.7' '8.0')
	select_version
	install_dir_set
	output_option '请选择mysql版本' 'mysql普通版 galera版' 'branch'
	if [[ ${branch} = '1' ]];then
		url='https://repo.huaweicloud.com/mysql/Downloads'
	else
		if [[ ${os_bit} = '32' ]];then
			diy_echo "不支持32位系统建议换成64系统" "${red}" "${error}"
			exit 1
		fi
		url='http://releases.galeracluster.com'
	fi
	online_version
}

mysql_down(){
	if [[ ${branch} = '1' ]];then
		if [[ ${os_bit} = '64' ]];then
			if [[ ${version_number} = '8.0' ]];then
				down_url="${url}/MySQL-${detail_version_number%.*}/mysql-${detail_version_number}-linux-glibc2.12-x86_64.tar.xz"
			else
				down_url="${url}/MySQL-${detail_version_number%.*}/mysql-${detail_version_number}-linux-glibc2.12-x86_64.tar.gz"
			fi
		else
			if [[ ${version_number} = '8.0' ]];then
				down_url="${url}/MySQL-${detail_version_number%.*}/mysql-${detail_version_number}-linux-glibc2.12-i686.tar.xz"
			else
				down_url="${url}/MySQL-${detail_version_number%.*}/mysql-${detail_version_number}-linux-glibc2.12-i686.tar.gz"
			fi
		fi
	else
		down_url="${url}/mysql-wsrep-${detail_version_number}/binary/mysql-wsrep-${detail_version_number}-linux-x86_64.tar.gz"
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}

}

mysql_install_set(){

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
	home_dir=${install_dir}/mysql
	mkdir -p ${home_dir}
	cp -rp ${tar_dir}/* ${home_dir}
	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum install -y perl-Module-Pluggable libaio autoconf boost-program-options
	if [[ $branch = 2 ]];then
		if [[ ${os_release} = 6 ]];then
			cat ${workdir}/config/mysql/galera6.repo >/etc/yum.repos.d/galera.repo
		elif [[ ${os_release} = 7 ]];then
			cat ${workdir}/config/mysql/galera7.repo >/etc/yum.repos.d/galera.repo
		fi
		yum install -y galera-3
	fi
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
	cat ${workdir}/config/mysql/standard_config.cnf >${home_dir}/my.cnf
}

mysql_multi_config_a(){
	cat ${workdir}/config/mysql/multi_config_a.cnf >${home_dir}/my.cnf
}

mysql_multi_config_b(){
	cat ${workdir}/config/mysql/multi_config_b.cnf >>${home_dir}/my.cnf
}

mysql_multi_config_c(){
	cat ${workdir}/config/mysql/multi_config_c.cnf >>${home_dir}/my.cnf
}

mysql_config(){

	#通用配置
	sed -i "s#socket  = /usr/local/mysql/data#socket  = ${mysql_data_dir}#" ${home_dir}/my.cnf
	sed -i "s#basedir = /usr/local/mysql#basedir = ${home_dir}#" ${home_dir}/my.cnf
	sed -i "s#datadir = /usr/local/mysql/data#datadir = ${mysql_data_dir}#" ${home_dir}/my.cnf
	if [[ ${total_mem} -le 1024 && ${total_mem} -gt 0 ]];then
		sed -i 's/innodb_buffer_pool_size.*/innodb_buffer_pool_size = 256M/' ${home_dir}/my.cnf
	fi
	if [[ ${total_mem} -le 2048 && ${total_mem} -gt 1024 ]];then
		sed -i 's/innodb_buffer_pool_size.*/innodb_buffer_pool_size = 512M/' ${home_dir}/my.cnf
	fi
	if [[ ${total_mem} -le 4096 && ${total_mem} -gt 2048 ]];then
		sed -i 's/innodb_buffer_pool_size.*/innodb_buffer_pool_size = 1G/' ${home_dir}/my.cnf
	fi
	if [[ ${total_mem} -le 8192 && ${total_mem} -gt 4096 ]];then
		sed -i 's/innodb_buffer_pool_size.*/innodb_buffer_pool_size = 2G/' ${home_dir}/my.cnf
	fi
	if [[ ${total_mem} -gt 8192 ]];then
		sed -i 's/innodb_buffer_pool_size.*/innodb_buffer_pool_size = 4G/' ${home_dir}/my.cnf
	fi
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
		add_daemon_file	${home_dir}/mysqld.service
		add_system_service mysqld ${home_dir}/mysqld.service y
		service_control mysqld start
	elif [[ ${deploy_mode} = '2' ]];then
		if [[ ${os_release} > 6 ]];then
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf --log=/tmp/mysql_multi.log start %i"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop %i"
			add_daemon_file ${home_dir}/mysqld.service
			add_system_service mysqld@3306 ${home_dir}/mysqld.service
			service_control mysqld@3306 start
		else
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf start \$2"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop \$2"
			add_daemon_file
			add_system_service mysqld_multi ${home_dir}/mysqld.service
			service_control 'mysqld_multi 3306' start
		fi
	fi

}

mysql_first_password_set(){
	sleep 15
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
	mysql_env_load
	mysql_install_set
	mysql_down
	mysql_install
	
}