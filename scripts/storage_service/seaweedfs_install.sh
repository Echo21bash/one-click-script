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
	cat >${home_dir}/etc/weedmaster<<-EOF
	PORT=9333
	MDIR=${seaweedfs_data_dir}/weedmaster
	#Prometheus metrics listen port
	METRICSPORT=10000
	EOF
	cat >${home_dir}/etc/weedvolume<<-EOF
	PORT=8080
	#directories to store data files. dir[,dir]...
	DIR=${seaweedfs_data_dir}/weedvolume
	#comma-separated master servers
	MSERVER=127.0.0.1:9333
	#Prometheus metrics listen port
	METRICSPORT=10001
	#current volume server's data center name
	DATACENTER=dc1
	#current volume server's rack name
	RACK=rack1
	MAX=100
	EOF
	cat >${home_dir}/etc/weedfiler<<-EOF
	PORT=8888
	DIR=${seaweedfs_data_dir}/weedfiler
	MASTER=127.0.0.1:9333
	#Prometheus metrics listen port
	METRICSPORT=10002
	EOF
	
	cat >${home_dir}/etc/weedadmin<<-EOF
	ADMINUSER=admin
	ADMINPASSWORD=admin
	PORT=23646
	DATADIR=${seaweedfs_data_dir}/weedadmin
	MASTERS=127.0.0.1:9333
	EOF


}

add_seaweedfs_service(){
	if [[ ${deploy_mode} = '1' ]];then
		Type=simple
		EnvironmentFile="${home_dir}/etc/weedmaster"
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed master"
		add_daemon_file ${home_dir}/seaweedmaster.service
		add_system_service seaweedmaster ${home_dir}/seaweedmaster.service
		service_control seaweedmaster restart
		
		Type=simple
		EnvironmentFile="${home_dir}/etc/weedvolume"
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed volume"
		add_daemon_file ${home_dir}/seaweedvolume.service
		add_system_service seaweedvolume ${home_dir}/seaweedvolume.service
		service_control seaweedvolume restart
		
		Type=simple
		EnvironmentFile="${home_dir}/etc/weedfiler"
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed filer"
		add_daemon_file ${home_dir}/seaweedfiler.service
		add_system_service seaweedfiler ${home_dir}/seaweedfiler.service
		service_control seaweedfiler restart
		
		Type=simple
		EnvironmentFile="${home_dir}/etc/weedadmin"
		WorkingDirectory="${home_dir}"
		ExecStart="${home_dir}/bin/weed admin"
		add_daemon_file ${home_dir}/seaweedadmin.service
		add_system_service seaweedadmin ${home_dir}/seaweedadmin.service
		service_control seaweedadmin restart
	fi

}

seaweedfs_install(){
	if [[ ${deploy_mode} = '1' ]];then
		home_dir=${install_dir}/seaweedfs
		mkdir -p ${home_dir}
		mkdir -p ${home_dir}/{bin,etc}
		mkdir -p ${seaweedfs_data_dir}/{weedmaster,weedvolume,weedfiler,weedadmin}
		mkdir -p /root/.seaweedfs
		cp ${tmp_dir}/weed ${home_dir}/bin/weed
		cp ${workdir}/config/seaweedfs/filer.toml /root/.seaweedfs/
		sed -i "s#dir = \"./filerldb3\"#dir = \"${seaweedfs_data_dir}/weedfiler/filerldb3\"#" /root/.seaweedfs/filer.toml
		add_seaweedfs_service
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
	fi

}


seaweedfs_install_ctl(){
	seaweedfs_env_load
	seaweedfs_install_set
	seaweedfs_down
	seaweedfs_install
	seaweedfs_config
	add_seaweedfs_service
	service_control seaweedfs
}
