#!/bin/bash

minio_env_load(){

	soft_name=minio
	tmp_dir=/usr/local/src/minio_tmp
	mkdir -p ${tmp_dir}
	url='https://dl.minio.io/server/minio/release/linux-amd64/minio'
	install_dir_set
}

minio_install_set(){
	output_option "请选择安装模式" "单机模式 集群模式" "deploy_mode"
	input_option "请输入minio端口" "9000" "minio_port"
	input_option "请输入minio存储路径" "/data/minio" "data_dir"
	data_dir=${input_value}
	input_option "请输入minio账号key(>=3位)" "minio" "minio_access"
	minio_access=${input_value}
	input_option "请输入minio认证key(8-40位)" "12345678" "minio_secret"
	minio_secret=${input_value}
}

minio_down(){
	#server
	down_url='https://dl.minio.io/server/minio/release/linux-amd64/minio'
	online_down_file
	#client
	down_url='https://dl.min.io/client/mc/release/linux-amd64/mc'
	online_down_file
}

minio_config(){

	home_dir=${install_dir}/minio
	mkdir -p ${home_dir}/{bin,etc}
	mkdir -p ${data_dir}
	cp ${tmp_dir}/minio ${home_dir}/bin/minio
	cp ${tmp_dir}/mc ${home_dir}/bin/mc
	chmod +x ${home_dir}/bin/minio
	chmod +x ${home_dir}/bin/mc
	cat >${home_dir}/etc/minio<<-EOF
	MINIO_ACCESS_KEY=${minio_access}
	MINIO_SECRET_KEY=${minio_secret}
	MINIO_VOLUMES=${data_dir}
	MINIO_OPTS="-C ${home_dir}/etc --address :${minio_port}"
	EOF
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_minio_service(){
	EnvironmentFile="${home_dir}/etc/minio"
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES"
	#ARGS="&"
	add_daemon_file ${home_dir}/minio.service
	add_system_service minio ${home_dir}/minio.service
}

minio_install_ctl(){
	minio_env_load
	minio_install_set
	minio_down
	minio_config
	add_minio_service
	service_control minio
}
