#!/bin/bash

greenplum_env_load(){
	
	tmp_dir=/usr/local/src/greenplum_tmp
	mkdir -p ${tmp_dir}
	soft_name=greenplum
	program_version=('6')
	url='https://github.com/greenplum-db/gpdb'
	select_version
	online_version

}

greenplum_install_set(){
	vi ${workdir}/config/greenplum/greenplum.conf
	. ${workdir}/config/greenplum/greenplum.conf

}

greenplum_down(){
	if [[ ${os_release} = '6' ]];then
		down_url="${url}/releases/download/${detail_version_number}/greenplum-db-${detail_version_number}-rhel6-x86_64.rpm"
	fi
	if [[ ${os_release} = '7' ]];then
		down_url="${url}/releases/download/${detail_version_number}/greenplum-db-${detail_version_number}-rhel7-x86_64.rpm"
	fi
	online_down_file
}

greenplum_install_env(){
	auto_ssh_keygen
	local i=0
	for host in ${host_ip[@]};
	do
		scp -P ${ssh_port[i]} ${workdir}/scripts/public.sh root@${host}:/root
		scp -P ${ssh_port[i]} ${workdir}/scripts/other/system_optimize.sh root@${host}:/root
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		. /root/public.sh
		. /root/system_optimize.sh
		system_optimize_set
		rm -rf /root/public.sh /root/system_optimize.sh
		useradd gpadmin
		echo 'passw0ord!@#123' | passwd --stdin gpadmin"
		((i++))
	done

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
	info_log "正在下载greenplum备份恢复工具"
	down_file https://github.com/greenplum-db/gpbackup/releases/download/1.19.0/gpbackup ${tmp_dir}/gpbackup
	down_file https://github.com/greenplum-db/gpbackup/releases/download/1.19.0/gprestore ${tmp_dir}/gprestore
	chmod +x ${tmp_dir}/gpbackup ${tmp_dir}/gprestore
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
		yum install -y greenplum-db-${detail_version_number}-rhel7-x86_64.rpm
		chown -R gpadmin.gpadmin /usr/local/greenplum-db*
		hostnamectl set-hostname ${host_name[$i]}
		greenplum_bin="\`grep -o 'greenplum_path' /home/gpadmin/.bashrc\`"
		[[ x\${greenplum_bin} = x ]] && echo 'source /usr/local/greenplum-db/greenplum_path.sh' >>/home/gpadmin/.bashrc
		EOF
		scp -P ${ssh_port[i]} ${tmp_dir}/{gpbackup,gprestore} root@${host}:/usr/local/greenplum-db/bin/
		((i++))
	done
	
	#配置主机名免密
	host_ip=(${host_name[@]})
	auto_ssh_keygen
	#配置主机免密
	host_ip=(${host_name[@]})
	user=gpadmin
	passwd='passw0ord!@#123'
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
		chown -R gpadmin.gpadmin ${mirror_data_dir[@]}
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
	
	su gpadmin -c "ssh ${master_name} 'gpinitsystem -a -c gpconfigs/gpinitsystem_config -h gpconfigs/hostfile_gpinitsystem --mirror-mode=group'"
	#ssh ${master_name} <<-EOF
	#su - gpadmin
	#gpinitsystem -c gpconfigs/gpinitsystem_config -h gpconfigs/hostfile_gpinitsystem
	#EOF
	gpstatus=`su - gpadmin -c "psql -q -d postgres  -c 'select current_database();' | awk 'NR==3'" | sed 's/ //'`
	if [[ ${gpstatus} = 'postgres' ]];then
		diy_echo "完成初始化Greenplum集群..." "${info}"
	else
		diy_echo "初始化Greenplum集群失败!!!" "${red}" "${error}"
		exit
	fi
	MASTER_DATA_DIRECTORY="${master_data_dir}/`ssh ${master_name} "ls ${master_data_dir}"`"
	ssh ${master_name} <<-EOF
	su - gpadmin
	[[ x\$MASTER_DATA_DIRECTORY = x ]] && echo "export MASTER_DATA_DIRECTORY=$MASTER_DATA_DIRECTORY" >>.bashrc
	EOF

}


greenplum_install_ctl(){
	greenplum_env_load
	greenplum_install_set
	greenplum_down
	greenplum_install_env
	greenplum_install
	greenplum_config
	
}