#!/bin/bash

greenplum_env_load(){
	. ${workdir}/config/greenplum/greenplum.conf
	auto_ssh_keygen
	tmp_dir=/tmp/greenplum_tmp
	mkdir -p ${tmp_dir}
	soft_name=greenplum
	program_version=('6')
	url='https://github.com/greenplum-db/gpdb'
	down_url="${greenplum_url}/releases/${online_select_version}/greenplum-db-${online_select_version}-rhel6-x86_64.rpm"
	curl -sL -o /tmp/all_version ${url}/tags
}


greenplum_install_env(){

	local i=0
	for host in ${host_name[@]};
	do
	scp -P ${ssh_port[i]} ${workdir}/scripts/{public.sh,system_optimize.sh} root@${host}:/root
	ssh ${host_name[$i]} -p ${ssh_port[$i]} "
	. /root/public.sh
	. /root/system_optimize.sh
	conf=(1 2 4 5 6 7)
	system_optimize_set
	rm -rf /root/public.sh /root/system_optimize.sh"
	((i++))
	done
}

greenplum_install_set(){



}

greenplum_install(){
	downfile ${down_url}
	local i=0
	for host in ${host_name[@]};
	do
	scp -P ${ssh_port[i]} ${workdir}/scripts/{public.sh,system_optimize.sh} root@${host}:/root
	ssh ${host_name[$i]} -p ${ssh_port[$i]} "yum install greenplum-db-6.7.0-rhel7-x86_64.rpm"
	((i++))
	done
}

greenplum_config(){
	get_ip
	mkdir -p ${home_dir}/{logs,etc,data}
	conf_dir=${home_dir}/etc
	cp ${tar_dir}/greenplum.conf ${conf_dir}/greenplum.conf
	sed -i "s/^bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/greenplum.conf
	sed -i 's/^port 6379/port '${greenplum_port}'/' ${conf_dir}/greenplum.conf
	sed -i 's/^daemonize no/daemonize yes/' ${conf_dir}/greenplum.conf
	sed -i "s#^pidfile .*#pidfile ${home_dir}/data/greenplum.pid#" ${conf_dir}/greenplum.conf
	sed -i 's#^logfile ""#logfile "'${home_dir}'/logs/greenplum.log"#' ${conf_dir}/greenplum.conf
	sed -i 's#^dir ./#dir '${home_dir}'/data#' ${conf_dir}/greenplum.conf
	sed -i 's/# requirepass foobared/requirepass '${greenplum_password}'/' ${conf_dir}/greenplum.conf
	sed -i 's/# maxmemory <bytes>/maxmemory 100mb/' ${conf_dir}/greenplum.conf
	sed -i 's/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/' ${conf_dir}/greenplum.conf
	sed -i 's/appendonly no/appendonly yes/' ${conf_dir}/greenplum.conf
	
	if [ ${deploy_mode} = '1' ];then
		add_log_cut greenplum ${home_dir}/logs/*.log
	elif [ ${deploy_mode} = '2' ];then
		if [[ ${cluster_mode} = '1' ]];then
			mkdir -p ${install_dir}/bin
			cp ${tar_dir}/src/greenplum-trib.rb ${install_dir}/bin/greenplum-trib.rb
			sed -i 's/^# masterauth <master-password>/masterauth '${greenplum_password}'/' ${conf_dir}/greenplum.conf
			sed -i 's/# cluster-enabled yes/cluster-enabled yes/' ${conf_dir}/greenplum.conf
			sed -i 's/# cluster-config-file nodes-6379.conf/cluster-config-file nodes-'${greenplum_port}'.conf/' ${conf_dir}/greenplum.conf
			sed -i 's/# cluster-node-timeout 15000/cluster-node-timeout 15000/' ${conf_dir}/greenplum.conf
		elif [[ ${cluster_mode} = '2' ]];then
			cp ${tar_dir}/sentinel.conf ${conf_dir}/sentinel.conf
			sed -i 's/^# masterauth <master-password>/masterauth '${greenplum_password}'/' ${conf_dir}/greenplum.conf
			if [[ ${node_type} = 'M' && ${i} != '1' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_greenplum_ip} ${mast_greenplum_port}/" ${conf_dir}/greenplum.conf
			elif [[  ${node_type} = 'S' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_greenplum_ip} ${mast_greenplum_port}/" ${conf_dir}/greenplum.conf
			fi
			#哨兵配置文件
			sed -i "s/^# bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/sentinel.conf
			sed -i "s/^port 26379/port 2${greenplum_port}/" ${conf_dir}/sentinel.conf
			sed -i "s#^dir /tmp#dir ${home_dir}/data\nlogfile ${home_dir}/log/sentinel.log\npidfile ${home_dir}/data/greenplum_sentinel.pid\ndaemonize yes#" ${conf_dir}/sentinel.conf
			sed -i "s#^sentinel monitor mymaster 127.0.0.1 6379 2#sentinel monitor mymaster ${local_ip} ${mast_greenplum_port} 2#" ${conf_dir}/sentinel.conf
			sed -i 's!^# sentinel auth-pass mymaster.*!sentinel auth-pass mymaster '${greenplum_password}'!' ${conf_dir}/sentinel.conf
		fi
		add_log_cut greenplum_${greenplum_port} ${home_dir}/logs/*.log
	fi

}


greenplum_install_ctl(){
	greenplum_env_load
	greenplum_install_set
	install_set
	greenplum_install
	clear_install
}