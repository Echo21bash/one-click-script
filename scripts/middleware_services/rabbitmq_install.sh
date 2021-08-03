#!/bin/bash

rabbitmq_env_load(){
	
	tmp_dir=/usr/local/src/rabbitmq_tmp
	mkdir -p ${tmp_dir}
	soft_name=rabbitmq
	program_version=('3.7' '3.8')
	url='https://repo.huaweicloud.com/rabbitmq-server'
	select_version
	install_dir_set
	online_version

}

rabbitmq_down(){

	down_url="${url}/v${detail_version_number}/rabbitmq-server-generic-unix-${detail_version_number}.tar.xz"
	online_down_file
	unpacking_file ${tmp_dir}/rabbitmq-server-generic-unix-${detail_version_number}.tar.xz ${tmp_dir}

}


rabbitmq_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		rabbitmq_env_check
		input_option '请设置rabbitmq的主机名称' 'node1' 'rabbitmq_nodename'
		rabbitmq_nodename=${input_value}
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/rabbitmq/rabbitmq-cluster.conf
		. ${workdir}/config/rabbitmq/rabbitmq-cluster.conf
	fi

}

rabbitmq_env_check(){
	erl -version >/dev/null 2>&1
	if [[ $? = 0 ]];then
		success_log "erlang运行环境已具备注意与rabbitmq版本对应关系"
	else
		error_log "erlang运行环境没有安装请安装"
	fi
}

rabbitmq_install(){ 

	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/rabbitmq
		mkdir -p ${home_dir}
		cp -rp ${tar_dir}/* ${home_dir}
		add_sys_env "PATH=${home_dir}/sbin:\$PATH"
		rabbitmq_config
		add_rabbitmq_service
	fi

	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			rabbitmq_port=5672
			rabbitmq_management_port=15672
			for ((j=0;j<${node_num[$k]};j++))
			do
				broker_id=$i
				let rabbitmq_port=5672+$j
				let rabbitmq_management_port=15672+$j
				rabbitmq_config
				home_dir=${install_dir}/rabbitmq-node${broker_id}
				add_rabbitmq_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${install_dir}/rabbitmq-node${broker_id}
				"
				info_log "正在向节点${now_host}分发rabbitmq-node${broker_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/rabbitmq-node${broker_id}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/rabbitmq-node${i}.service ${host_ip[$k]}:${install_dir}/rabbitmq-node${i}.service
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/log_cut_rabbitmq_node${i} ${host_ip[$k]}:${install_dir}/log_cut_rabbitmq_node${i}
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${install_dir}/rabbitmq-node${broker_id}/rabbitmq-node${i}.service /etc/systemd/system/rabbitmq-node${i}.service
				\cp ${install_dir}/rabbitmq-node${broker_id}/log_cut_rabbitmq_node${i} /etc/logrotate.d/rabbitmq-node${i}
				systemctl daemon-reload
				[[ -z `grep node${broker_id} /etc/hosts` ]] && echo 127.0.0.1    node${broker_id}>>/etc/hosts
				"
				((i++))
			done
			((k++))
		done
	fi
	
}


rabbitmq_config(){
	if [[ ${deploy_mode} = '1' ]];then
		if [[ -z `grep ${rabbitmq_nodename} /etc/hosts` ]];then
			echo 127.0.0.1   ${rabbitmq_nodename} >>/etc/hosts
		fi
		cat ${workdir}/config/rabbitmq/rabbitmq-env.conf >${home_dir}/etc/rabbitmq/rabbitmq-env.conf
		sed -i "s?RABBITMQ_NODENAME=.*?RABBITMQ_NODENAME=rabbit@${rabbitmq_nodename}?" ${home_dir}/etc/rabbitmq/rabbitmq-env.conf
		${home_dir}/sbin/rabbitmq-plugins enable rabbitmq_management
		add_log_cut ${home_dir}/log_cut_rabbitmq ${home_dir}/var/log/rabbitmq/*.log
		\cp ${home_dir}/log_cut_rabbitmq /etc/logrotate.d/rabbitmq

	if [[ ${deploy_mode} = '2' ]];then
		cat ${workdir}/config/rabbitmq/rabbitmq-env.conf >${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		cat ${workdir}/config/rabbitmq/rabbitmq.conf >${tar_dir}/etc/rabbitmq/rabbitmq.conf
		sed -i "s?RABBITMQ_NODENAME=.*?RABBITMQ_NODENAME=rabbit@${rabbitmq_nodename}?" ${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		sed -i "s?listeners.tcp.default.*?listeners.tcp.default = ${rabbitmq_port}?" ${tar_dir}/etc/rabbitmq/rabbitmq.conf
		sed -i "s?management.listener.port.*?management.listener.port = ${rabbitmq_management_port}?" ${tar_dir}/etc/rabbitmq/rabbitmq.
		add_log_cut ${tmp_dir}/log_cut_rabbitmq_node${i} ${home_dir}/var/log/rabbitmq/*.log
	fi
}

add_rabbitmq_service(){
	Type="forking"
	if [[ ${deploy_mode} = '1' ]];then
		ExecStart="${home_dir}/sbin/rabbitmq-server -detached"
		ExecStop="${home_dir}/sbin/rabbitmqctl shutdown"
		conf_system_service ${home_dir}/rabbitmq.service
		add_system_service rabbitmq ${home_dir}/rabbitmq.service
		
	elif [[ ${deploy_mode} = '2' ]];then
		ExecStart="${home_dir}/sbin/rabbitmq-server -detached"
		ExecStop="${home_dir}/sbin/rabbitmqctl shutdown"
		conf_system_service ${tmp_dir}/rabbitmq-node${i}.service
	fi
	
}

rabbitmq_install_ctl(){
	rabbitmq_env_load
	rabbitmq_install_set
	rabbitmq_down
	rabbitmq_install
}
