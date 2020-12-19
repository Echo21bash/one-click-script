#!/bin/bash

keepalived_env(){
	info_log "配置主机免密登录"
	auto_ssh_keygen

}

keepalived_install(){
	vi ${workdir}/config/keepalived/keepalived_cluster.conf
	. ${workdir}/config/keepalived/keepalived_cluster.conf

	local i=1
	for now_host in ${host_ip[@]}
	do

		info_log "正在向节点${now_host}keepalived配置文件..."
		scp -q -r -P ${ssh_port[$i]} ${workdir}/config/keepalived/keepalived.conf ${host_ip[$i]}:/etc/keepalived
		scp -q -r -P ${ssh_port[$i]} ${tmp_dir}/config/keepalived/check_script.sh ${host_ip[$i]}:/etc/keepalived
				
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		\cp ${install_dir}/zookeeper-node${service_id}/zookeeper-node${i}.service /etc/systemd/system/zookeeper-node${i}.service
		\cp ${install_dir}/zookeeper-node${service_id}/myid_node${service_id} ${zookeeper_data_dir}/node${service_id}/myid
		\cp ${install_dir}/zookeeper-node${service_id}/log_cut_zookeeper-node${i} /etc/logrotate.d/zookeeper-node${i}
		systemctl daemon-reload
		"
		((i++))
	done
}

keepalived_config(){
echo
}

keepalived_install_ctl(){
	keepalived_env
	keepalived_install

}