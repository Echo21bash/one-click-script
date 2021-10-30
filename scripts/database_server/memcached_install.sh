#!/bin/bash

memcached_env_load(){
	tmp_dir=/usr/local/src/memcached_tmp
	soft_name=memcached
	program_version=('1.4' '1.5')
	url="https://repo.huaweicloud.com/memcached"
	select_version
	install_dir_set
	online_version
}

memcached_down(){
	down_url="${url}/memcached-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/memcached-${detail_version_number}.tar.gz ${tmp_dir}
}

memcached_inistall_set(){
	output_option "请选择安装版本" "单机模式 双主模式(集成repcached补丁版)" "deploy_mode"
	if [[ ${deploy_mode} = '2' ]];then
		warning_log "集成repcached补丁,该补丁并非官方发布,目前最新补丁兼容1.4.13"
		vi ${workdir}/config/memcached/memcached-cluster.conf
		. ${workdir}/config/memcached/memcached-cluster.conf
	fi

}

memcached_install(){
	yum -y install make  gcc-c++ libevent libevent-devel
	make_home_dir=${tmp_dir}/memcached-bin
	mkdir -p ${make_home_dir}/{etc,logs}
	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/memcached
		mkdir -p ${home_dir}
		memcached_compile
		cp -rp ${make_home_dir}/* ${home_dir}
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
		memcached_config
		add_memcached_service
	fi

	if [[ ${deploy_mode} = '2' ]];then
		memcached_compile
		auto_ssh_keygen
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			memcached_port=11211
			memcached_syn_port=11221
			let host_id=$k+1
			for ((j=0;j<${node_num[$k]};j++))
			do
				node_id=$i
				let memcached_port=11211+$j
				let memcached_syn_port=11221+$j
				home_dir=${install_dir}/memcached-node${node_id}
				memcached_config
				add_memcached_service
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				mkdir -p ${home_dir}
				yum -y install libevent libevent-devel
				"
				info_log "正在向节点${now_host}分发memcached-node${node_id}安装程序和配置文件..."
				scp -q -r -P ${ssh_port[$k]} ${make_home_dir}/* ${host_ip[$k]}:${home_dir}
				scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{memcached-node${i}.service,logrotate-memcached-node${i}} ${host_ip[$k]}:${home_dir}/
				ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
				\cp ${home_dir}/memcached-node${i}.service /etc/systemd/system/memcached-node${i}.service
				\cp ${home_dir}/logrotate-memcached-node${i} /etc/logrotate.d/memcached-node${i}
				systemctl daemon-reload
				"
				((i++))
			done
			((k++))
		done
		
	fi
		
}

memcached_compile(){
	cd ${tmp_dir}/${package_root_dir}
	if [[ ${deploy_mode} = '1' ]];then
		./configure --prefix=${make_home_dir} && make -j 4 && make install
		if [[ $? = 0 ]];then
			success_log "编译完成"
		else
			error_log "编译失败"
			exit 1
		fi
	fi
	if [[ ${deploy_mode} = '2' ]];then
		online_down_file "http://mdounin.ru/files/repcached-2.3.1-1.4.13.patch.gz"
		gzip -d ${tmp_dir}/repcached-2.3.1-1.4.13.patch.gz 
		patch -p1 -i ../repcached-2.3.1-1.4.13.patch
		if [[ $? = 0 ]];then
			success_log "打补丁完成"
		else
			error_log "打补丁失败"
			exit 1
		fi
		./configure --prefix=${make_home_dir} --enable-replication && make -j 4 && make install
		if [[ $? = 0 ]];then
			success_log "编译完成"
		else
			error_log "编译失败"
			exit 1
		fi
	fi


}

memcached_config(){
	if [[ ${deploy_mode} = '1' ]];then
		cp ${workdir}/config/memcached/memcached ${home_dir}/etc/memcached
		sed -i "s?PORT="11211"?PORT=${memcached_port}?" ${home_dir}/etc/memcached
		add_log_cut ${home_dir}/logrotate-memcached ${home_dir}/logs/*.log
	fi

	if [[ ${deploy_mode} = '2' ]];then
		cp ${workdir}/config/memcached/memcached ${make_home_dir}/etc/memcached
		sed -i "s?PORT="11211"?PORT=${memcached_port}?" ${make_home_dir}/etc/memcached
		sed -i "s?OPTIONS=.*?OPTIONS='-x ${now_host} -X ${memcached_syn_port}'?" ${make_home_dir}/etc/memcached
		add_log_cut ${tmp_dir}/logrotate-memcached-node${i} ${home_dir}/logs/*.log
	fi

}

add_memcached_service(){
	Type="forking"
	if [[ ${deploy_mode} = '1' ]];then
		EnvironmentFile="${home_dir}/etc/memcached"
		ExecStart="${home_dir}/bin/memcached -d -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$LOG \$OPTIONS"
		add_daemon_file ${home_dir}/memcached.service
		add_system_service memcached "${home_dir}/memcached.service"
	fi

	if [[ ${deploy_mode} = '2' ]];then
		EnvironmentFile="${home_dir}/etc/memcached"
		ExecStart="${home_dir}/bin/memcached -d -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$LOG \$OPTIONS"
		add_daemon_file ${tmp_dir}/memcached-node${node_id}.service

	fi
}

memcached_inistall_ctl(){
	memcached_env_load
	memcached_inistall_set
	memcached_down
	memcached_install
	
}