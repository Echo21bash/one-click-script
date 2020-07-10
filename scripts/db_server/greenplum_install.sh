#!/bin/bash

greenplum_env_load(){
	. ${workdir}/config/greenplum/greenplum.conf
	
	tmp_dir=/tmp/greenplum_tmp
	mkdir -p ${tmp_dir}
	soft_name=greenplum
	program_version=('6')
	url='https://github.com/greenplum-db/gpdb'
	if [[ ${os_release} = '6' ]];then
		down_url='${greenplum_url}/releases/${detail_version_number}/greenplum-db-${detail_version_number}-rhel6-x86_64.rpm'
	fi
	if [[ ${os_release} = '7' ]];then
		down_url='${greenplum_url}/releases/${detail_version_number}/greenplum-db-${detail_version_number}-rhel7-x86_64.rpm'
	fi
}


greenplum_install_env(){
	auto_ssh_keygen
	local i=0
	for host in ${host_ip[@]};
	do
		scp -P ${ssh_port[i]} ${workdir}/scripts/{public.sh,system_optimize.sh} root@${host}:/root
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		. /root/public.sh
		. /root/system_optimize.sh
		conf=(1 2 4 5 6 7)
		system_optimize_set
		rm -rf /root/public.sh /root/system_optimize.sh
		useradd gpadmin
		echo 'gpadmin' | passwd --stdin gpadmin"
		((i++))
	done
	user=gpadmin
	passwd=('gpadmin' 'gpadmin' 'gpadmin')
	auto_ssh_keygen
}

greenplum_install_set(){

echo
}

greenplum_install(){
	
	host_num="${#host_ip[@]}"
	local i=0
	for host in ${host_ip[@]};
	do
		scp -P ${ssh_port[i]} ${tmp_dir}/${file_name} root@${host}:/root
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		yum install -y ${file_name}
		hostnamectl set-hostname ${host_name[$i]}
		"
	((i++))
	done
	

	for ((i=0,i<${host_num},i++));
	do
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		i=0
		for ip in ${host_ip[@]};do [[ -z `grep "${ip} ${host_name[$i]}" /etc/hosts` ]] && echo "${ip} ${host_name[$i]}">>/etc/hosts ((i++));done
		"
	done
}

greenplum_config(){
	echo
}


greenplum_install_ctl(){
	greenplum_env_load
	select_version
	online_version
	online_down_file
	unpacking_file
	greenplum_install_env
	greenplum_install_set
	greenplum_install
	clear_install
}