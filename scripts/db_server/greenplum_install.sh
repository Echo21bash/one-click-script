#!/bin/bash

greenplum_env_load(){
	. ${workdir}/config/greenplum/greenplum.conf
	
	tmp_dir=/tmp/greenplum_tmp
	mkdir -p ${tmp_dir}
	soft_name=greenplum
	program_version=('6')
	url='https://github.com/greenplum-db/gpdb'
	if [[ ${os_release} = '6' ]];then
		down_url='${url}/releases/download/${detail_version_number}/greenplum-db-${detail_version_number}-rhel6-x86_64.rpm'
	fi
	if [[ ${os_release} = '7' ]];then
		down_url='${url}/releases/download/${detail_version_number}/greenplum-db-${detail_version_number}-rhel7-x86_64.rpm'
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
		conf=(2 4 5 6 7)
		system_optimize_set
		rm -rf /root/public.sh /root/system_optimize.sh
		useradd gpadmin
		echo 'gpadmin' | passwd --stdin gpadmin"
		((i++))
	done

}

greenplum_install_set(){

echo
}

greenplum_install(){
	
	host_num="${#host_ip[@]}"
	
	#创建主机hosts文件
	local i=0
	>${tmp_dir}/hosts
	for host in ${host_ip[@]};
	do
		echo "${host_ip[$i]} ${host_name[$i]}">>${tmp_dir}/hosts
		((i++))
	done
	
	#发送安装包并安装
	local i=0
	for host in ${host_ip[@]};
	do
		scp -P ${ssh_port[i]} ${tmp_dir}/${file_name} root@${host}:/root
		scp -P ${ssh_port[i]} ${tmp_dir}/hosts root@${host}:/tmp

		ssh ${host_ip[$i]} -p ${ssh_port[$i]} <<-EOF
		host1=\`tail -n 1 /etc/hosts | awk '{print \$2}'\`
		host2=\`tail -n 1 /tmp/hosts | awk '{print \$2}'\`
		[[ \${host1} != \${host2} ]] && cat /tmp/hosts >>/etc/hosts
		yum install -y ${file_name}
		hostnamectl set-hostname ${host_name[$i]}
		cp /usr/local/greenplum-db/greenplum_path.sh /etc/profile.d/
		chmod +x /etc/profile.d/greenplum_path.sh
		EOF
		((i++))
	done
	
	#配置主机名免密
	host_ip=(${host_name[@]})
	auto_ssh_keygen
	#配置主机免密
	host_ip=(${host_name[@]})
	user=gpadmin
	passwd=('gpadmin' 'gpadmin' 'gpadmin')
	auto_ssh_keygen

}

greenplum_config(){
	
	sed -i "s#declare -a DATA_DIRECTORY=.*#declare -a DATA_DIRECTORY=(${data_dir[@]})#" ${workdir}/config/greenplum/gpinitsystem_config
	sed -i "s#MASTER_DIRECTORY=.*#MASTER_DIRECTORY=${master_data_dir[@]}#" ${workdir}/config/greenplum/gpinitsystem_config
	sed -i "s#MIRROR_DATA_DIRECTORY=.*#MIRROR_DATA_DIRECTORY=(${mirror_data_dir[@]})#" ${workdir}/config/greenplum/gpinitsystem_config
	sed -i "s#MASTER_HOSTNAME=.*#MASTER_HOSTNAME=${master_name[@]}#" ${workdir}/config/greenplum/gpinitsystem_config

	
	for host in ${data_name[@]};
	do 
		ssh ${host} <<-EOF
		mkdir -p ${data_dir[@]}
		mkdir -p ${mirror_data_dir[@]}
		chown -R gpadmin.gpadmin ${data_dir[@]}
		chown -R gpadmin.gpadmin ${mirror_data_dir[@]
		EOF
	done
	
	
	ssh ${master_name}  <<-EOF
	mkdir -p ${master_data_dir[@]}
	chown -R gpadmin.gpadmin ${master_data_dir[@]}
	su - gpadmin
	mkdir gpconfigs
	> ./gpconfigs/hostfile_exkeys
	> ./gpconfigs/hostfile_gpinitsystem
	for host in ${host_name[@]};do echo \${host}>>./gpconfigs/hostfile_exkeys;done
	for host in ${data_name[@]};do echo \${host}>>./gpconfigs/hostfile_gpinitsystem;done
	EOF

	ssh ${master_name} <<-EOF
	su - gpadmin
	gpssh-exkeys -f ./gpconfigs/hostfile_exkeys
	EOF
	scp ${workdir}/config/greenplum/gpinitsystem_config root@${master_name}:/home/gpadmin/gpconfigs
	
	ssh ${master_name} <<-EOF
	su - gpadmin
	gpinitsystem -c gpconfigs/gpinitsystem_config -h gpconfigs/hostfile_gpinitsystem
	EOF
	
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
	greenplum_config
	clear_install
}