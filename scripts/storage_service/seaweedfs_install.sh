#!/bin/bash

seaweedfs_env_load(){

	soft_name=seaweedfs
	tmp_dir=/usr/local/src/seaweedfs_tmp
	mkdir -p ${tmp_dir}
	program_version=('3')
	url='https://github.com/seaweedfs/seaweedfs'
	select_version
	install_dir_set
	online_version
}

seaweedfs_install_set(){
	output_option "请选择安装模式" "单机模式 集群模式" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/seaweedfs/seaweedfs-single.conf
		. ${workdir}/config/seaweedfs/seaweedfs-single.conf
	elif [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/seaweedfs/seaweedfs-cluster.conf
		. ${workdir}/config/seaweedfs/seaweedfs-cluster.conf
	fi
}

seaweedfs_down(){
	#server
	down_url="${url}/releases/download/${detail_version_number}/linux_amd64_full.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/linux_amd64_full.tar.gz ${tmp_dir}

}

seaweedfs_config(){
	
	if [[ ${deploy_mode} = '1' ]];then
		\cp ${workdir}/config/seaweedfs/master.conf ${home_dir}/etc/master.conf
		\cp ${workdir}/config/seaweedfs/volume.conf ${home_dir}/etc/volume.conf
		\cp ${workdir}/config/seaweedfs/filer.conf ${home_dir}/etc/filer.conf
		\cp ${workdir}/config/seaweedfs/admin.conf ${home_dir}/etc/admin.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${home_dir}/etc/master.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${home_dir}/etc/volume.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${home_dir}/etc/filer.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${home_dir}/etc/admin.conf
	fi

	if [[ ${deploy_mode} = '2' ]];then
		\cp ${workdir}/config/seaweedfs/master.conf ${tmp_dir}/master.conf
		\cp ${workdir}/config/seaweedfs/volume.conf ${tmp_dir}/volume.conf
		\cp ${workdir}/config/seaweedfs/filer.conf ${tmp_dir}/filer.conf
		\cp ${workdir}/config/seaweedfs/admin.conf ${tmp_dir}/admin.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${tmp_dir}/master.conf
		sed -i "s^#peers=^#peers=${master_peers}/^" ${tmp_dir}/master.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${tmp_dir}/volume.conf
		sed -i "s^mserver=127.0.0.1:9333^mserver=${master_peers}/^" ${tmp_dir}/volume.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${tmp_dir}/filer.conf
		sed -i "s^master=127.0.0.1:9333^master=${master_peers}/^" ${tmp_dir}/filer.conf
		sed -i "s^/data/seaweedfs/^${seaweedfs_data_dir}/^" ${tmp_dir}/admin.conf
		sed -i "s^masters=127.0.0.1:9333^masters=${master_peers}/^" ${tmp_dir}/admin.conf
	fi

}

add_seaweedfs_service(){

	if [[ ${deploy_mode} = '1' ]];then
		Type=simple
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed master -options=${home_dir}/etc/master.conf"
		add_daemon_file ${home_dir}/seaweedmaster.service
		add_system_service seaweedmaster ${home_dir}/seaweedmaster.service
		service_control seaweedmaster restart
		
		Type=simple
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed volume -options=${home_dir}/etc/volume.conf"
		add_daemon_file ${home_dir}/seaweedvolume.service
		add_system_service seaweedvolume ${home_dir}/seaweedvolume.service
		service_control seaweedvolume restart
		
		Type=simple
		WorkingDirectory="${seaweedfs_data_dir}/weedfiler"
		ExecStart="${home_dir}/bin/weed filer -options=${home_dir}/etc/filer.conf"
		add_daemon_file ${home_dir}/seaweedfiler.service
		add_system_service seaweedfiler ${home_dir}/seaweedfiler.service
		service_control seaweedfiler restart
		
		Type=simple
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed admin -options=${home_dir}/etc/admin.conf"
		add_daemon_file ${home_dir}/seaweedadmin.service
		add_system_service seaweedadmin ${home_dir}/seaweedadmin.service
		service_control seaweedadmin restart
	fi

}

seaweedfs_install(){
	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/seaweedfs
		mkdir -p ${home_dir}/{bin,etc}
		mkdir -p ${seaweedfs_data_dir}/{weedmaster,weedvolume,weedfiler,weedadmin}
		mkdir -p /root/.seaweedfs
		cp ${tmp_dir}/weed ${home_dir}/bin/weed
		cp ${workdir}/config/seaweedfs/filer.toml /root/.seaweedfs/
		seaweedfs_config
		add_seaweedfs_service
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
		ln -s ${home_dir}/bin/weed /usr/bin/weed
		ln -s ${home_dir}/bin/weed /usr/sbin/weed
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local k=0
		for now_host in ${host_ip[@]}
		do
			home_dir=${install_dir}/seaweedfs
			get_seaweedfs_master_node
			seaweedfs_config
			info_log "正在向节点${now_host}分发seaweedfs安装程序和配置文件..."
			case "${master_ip[*]}" in
				*"$now_host"*)
					auto_input_keyword "
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					mkdir -p ${seaweedfs_data_dir}/{weedmaster,weedadmin}
					mkdir -p ${home_dir}/{bin,etc}
					EOF
					scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${home_dir}/bin
					scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/{master,admin}.conf ${host_ip[$k]}:${home_dir}/etc
					scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					. /tmp/public.sh
					Type=simple
					WorkingDirectory="${home_dir}"
					ExecStart=\"${home_dir}/bin/weed master -options=${home_dir}/etc/master.conf\"
					add_daemon_file ${home_dir}/seaweedmaster.service
					add_system_service seaweedmaster ${home_dir}/seaweedmaster.service
					service_control seaweedmaster restart

					ExecStart=\"${home_dir}/bin/weed admin -options=${home_dir}/etc/admin.conf\"
					add_daemon_file ${home_dir}/seaweedadmin.service
					add_system_service seaweedadmin ${home_dir}/seaweedadmin.service
					service_control seaweedadmin restart
					rm -rf /tmp/public.sh
					EOF" "${passwd[$k]}"				
				;;
			esac
			
			case "${volume_ip[*]}" in
				*"$now_host"*)
					auto_input_keyword "
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					mkdir -p ${seaweedfs_data_dir}/weedvolume
					mkdir -p ${home_dir}/{bin,etc}
					EOF
					scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${home_dir}/bin
					scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
					scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/volume.conf ${host_ip[$k]}:${home_dir}/etc
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					. /tmp/public.sh
					Type=simple
					WorkingDirectory="${home_dir}"
					ExecStart=\"${home_dir}/bin/weed volume -options=${home_dir}/etc/volume.conf\"
					add_daemon_file ${home_dir}/seaweedvolume.service
					add_system_service seaweedvolume ${home_dir}/seaweedvolume.service
					service_control seaweedvolume restart
					rm -rf /tmp/public.sh
					EOF" "${passwd[$k]}"				
				;;
			esac
			case "${filer_ip[*]}" in
				*"$now_host"*)
					auto_input_keyword "
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					mkdir -p ${seaweedfs_data_dir}/weedfiler
					mkdir -p ${home_dir}/{bin,etc}
					mkdir -p /root/.seaweedfs/
					EOF
					scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${home_dir}/bin
					scp -q -r -P ${ssh_port[$k]} ${workdir}/config/seaweedfs/filer.toml ${host_ip[$k]}:/root/.seaweedfs/
					scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
					scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/filer.conf ${host_ip[$k]}:${home_dir}/etc
					ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
					. /tmp/public.sh
					Type=simple
					WorkingDirectory=\"${seaweedfs_data_dir}/weedfiler\"
					ExecStart=\"${home_dir}/bin/weed filer -options=${home_dir}/etc/filer.conf\"
					add_daemon_file ${home_dir}/seaweedfiler.service
					add_system_service seaweedfiler ${home_dir}/seaweedfiler.service
					service_control seaweedfiler restart
					rm -rf /tmp/public.sh
					EOF" "${passwd[$k]}"				
				;;
			esac
		done
	fi
}

get_seaweedfs_master_node(){
	master_peers=
	for master_peers in ${master_ip[*]}; do
		master_peers=${master_peers}:9333,
	done
}

seaweedfs_install_ctl(){
	seaweedfs_env_load
	seaweedfs_install_set
	seaweedfs_down
	seaweedfs_install
	
}
