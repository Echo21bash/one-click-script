#!/bin/bash

rhcs_install_set(){
	input_option "输入集群名称" "ha_cluster" "cluster_name"
	cluster_name=${input_value}
	diy_echo "首先配置管理主机免密登录各节点" "${yellow}" "${info}" 
	auto_ssh_keygen
	node_name=(${host_name[@]})
	ssh_port=(${port[@]})
}

rhcs_install(){
	diy_echo "正在安装rhcs组件..." "" "${info}"
	local i
	i=0
	if [[ ${os_release} = 6 ]];then
		for host in ${node_name[@]}
		do
			((i++))
			ssh root@${host} -p ${ssh_port[$i]}<<-EOF
			yum install -y pacemaker
			exit
			EOF
		done
	fi

	if [[ ${os_release} = 7 ]];then
		for host in ${node_name[@]}
		do
			((i++))
			ssh root@${host} -p ${ssh_port[$i]}<<-EOF
			yum install -y pacemaker pcs && systemctl start pcsd && systemctl enable pcsd
			echo 123456 | passwd --stdin hacluster
			exit
			EOF
		done
	fi

}

rhcs_install_ctl(){
	rhcs_install_set
	rhcs_install


}