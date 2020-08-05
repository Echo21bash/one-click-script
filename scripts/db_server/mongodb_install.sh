#!/bin/bash
mongodb_env_load(){
	tmp_dir=/tmp/mongodb_tmp
	soft_name=mongodb
	program_version=('3.4' '3.6' '4.0')
	url='https://www.mongodb.org/dl/linux'
	if [[ ${os_bit} = '32' ]];then
		diy_echo "mongodb不支持32位系统" "${red}" "${error}"
		exit 1
	fi
	down_url='http://downloads.mongodb.org/linux/mongodb-linux-x86_64-${detail_version_number}.tgz'
}

mongodb_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	input_option '请输入本机部署个数' '1' 'deploy_num'
	input_option '请输入起始端口号' '27017' 'mongodb_port'
	input_option '请输入数据存储路径' '/data' 'mongodb_data_dir'
	mongodb_data_dir=${input_value}
}

mongodb_install(){
	cp -rp ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/{etc,logs}
	mkdir -p ${mongodb_data_dir}
	mongodb_config
	add_mongodb_service
}

mongodb_config(){
	conf_dir=${home_dir}/etc
	cp ${workdir}/config/mongodb/mongodb.conf ${conf_dir}/mongodb.conf

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
	add_system_service mongodb ${home_dir}/init
}

mongodb_inistall_ctl(){
	mongodb_env_load
	mongodb_install_set
	select_version
	install_dir_set
	online_version
	online_down_file
	unpacking_file
	mongodb_install
	clear_install
}