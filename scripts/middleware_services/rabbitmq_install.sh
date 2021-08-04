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
		rabbitmq_hosts
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			rabbitmq_port=5672
			rabbitmq_management_port=15672
			let host_id=$k+1
			for ((j=0;j<${node_num[$k]};j++))
			do
				broker_id=$i
				let rabbitmq_port=5672+$j
				let rabbitmq_management_port=15672+$j
				home_dir=${install_dir}/rabbitmq-broker${broker_id}
				rabbitmq_config
				add_rabbitmq_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${home_dir}
				"
				info_log "正在向节点${now_host}分发rabbitmq-broker${broker_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${home_dir}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{rabbitmq-broker${i}.service,log_cut_rabbitmq_broker${i},hosts} ${host_ip[$k]}:${home_dir}/
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${home_dir}/rabbitmq-broker${i}.service /etc/systemd/system/rabbitmq-broker${i}.service
				\cp ${home_dir}/log_cut_rabbitmq_broker${i} /etc/logrotate.d/rabbitmq-broker${i}
				${home_dir}/sbin/rabbitmq-plugins enable rabbitmq_management
				systemctl daemon-reload
				grep -o rabbitmq-node${host_id} /etc/hosts || cat ${home_dir}/hosts >>/etc/hosts
				"
				((i++))
			done
			((k++))
		done
		rabbitmq_cluster_init
	fi
	
}


rabbitmq_config(){
	if [[ ${deploy_mode} = '1' ]];then
		get_ip
		if [[ -z `grep ${rabbitmq_nodename} /etc/hosts` ]];then
			echo ${local_ip}   ${rabbitmq_nodename} >>/etc/hosts
		fi
		cat ${workdir}/config/rabbitmq/rabbitmq-env.conf >${home_dir}/etc/rabbitmq/rabbitmq-env.conf
		sed -i "s?RABBITMQ_NODENAME=.*?RABBITMQ_NODENAME=${rabbitmq_nodename}?" ${home_dir}/etc/rabbitmq/rabbitmq-env.conf
		${home_dir}/sbin/rabbitmq-plugins enable rabbitmq_management
		add_log_cut ${home_dir}/log_cut_rabbitmq ${home_dir}/var/log/rabbitmq/*.log
		\cp ${home_dir}/log_cut_rabbitmq /etc/logrotate.d/rabbitmq
	fi

	if [[ ${deploy_mode} = '2' ]];then
		cat ${workdir}/config/rabbitmq/rabbitmq-env.conf >${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		cat ${workdir}/config/rabbitmq/rabbitmq.conf >${tar_dir}/etc/rabbitmq/rabbitmq.conf
		sed -i "s?RABBITMQ_NODENAME=.*?RABBITMQ_NODENAME=broker${broker_id}@rabbitmq-node${host_id}?" ${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		sed -i "s?RABBITMQ_NODE_PORT.*?RABBITMQ_NODE_PORT=${rabbitmq_port}?" ${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		sed -i "s?15672?${rabbitmq_management_port}?" ${tar_dir}/etc/rabbitmq/rabbitmq-env.conf
		add_log_cut ${tmp_dir}/log_cut_rabbitmq_broker${i} ${home_dir}/var/log/rabbitmq/*.log
	fi
}

add_rabbitmq_service(){
	Type="forking"
	if [[ ${deploy_mode} = '1' ]];then
		ExecStart="${home_dir}/sbin/rabbitmq-server -detached"
		ExecStop="${home_dir}/sbin/rabbitmqctl shutdown"
		SuccessExitStatus=69
		conf_system_service ${home_dir}/rabbitmq.service
		add_system_service rabbitmq ${home_dir}/rabbitmq.service
		
	elif [[ ${deploy_mode} = '2' ]];then
		ExecStart="${home_dir}/sbin/rabbitmq-server -detached"
		ExecStop="${home_dir}/sbin/rabbitmqctl shutdown"
		SuccessExitStatus=69
		conf_system_service ${tmp_dir}/rabbitmq-broker${i}.service
	fi
	
}

rabbitmq_hosts(){
	rm -rf ${tmp_dir}/hosts
	local i=1
	for now_host in ${host_ip[@]}
	do
		echo "${now_host}    rabbitmq-node$i">>${tmp_dir}/hosts
		((i++))
	done
}

rabbitmq_cluster_init(){
	local i=1
	local k=0
	for now_host in ${host_ip[@]}
	do
		let host_id=$k+1
		for ((j=0;j<${node_num[$k]};j++))
		do
			if [[ $i = '1' ]];then
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				systemctl start rabbitmq-broker$i && sleep 10 && \
				${install_dir}/rabbitmq-node$i/sbin/rabbitmqctl add_user ${admin_user} ${admin_pass} && \
				${install_dir}/rabbitmq-node$i/sbin/rabbitmqctl set_user_tags ${admin_user} administrator
				"
				scp -r ${host_ip[$i]}:/root/.erlang.cookie ${tmp_dir}
			else
				scp -r ${tmp_dir}/.erlang.cookie ${host_ip[$k]}:/root/
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				systemctl start rabbitmq-broker$i && sleep 10 && \
				${install_dir}/rabbitmq-node$i/sbin/rabbitmqctl stop_app && \
				${install_dir}/rabbitmq-node$i/sbin/rabbitmqctl join_cluster broker1@rabbitmq-node1 && \
				${install_dir}/rabbitmq-node$i/sbin/rabbitmqctl start_app
				"
				if [[ $? = 0 ]];then
					success_log "rabbitmq-broker$i 加入集群"
				else
					error_log "rabbitmq-broker$i 加入集群"
					exit 1
				fi
			fi
			((i++))
		done
		((k++))
	done
	success_log "完成rabbitmq集群初始化"

}

rabbitmq_install_ctl(){
	rabbitmq_env_load
	rabbitmq_install_set
	rabbitmq_down
	rabbitmq_install
}
