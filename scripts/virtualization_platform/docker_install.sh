#!/bin/bash

docker_install_ctl(){

	[[ -n `which dockerd 2>/dev/null` ]] && diy_echo "检测到可能已经安装docker请检查..." "${yellow}" "${warning}" && exit 1
	diy_echo "正在安装docker..." "" "${info}"
	system_optimize_yum
	if [[ ${os_release} < "7" ]];then
		yum install -y docker
	else
		down_file http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
		yum install -y docker-ce
	fi
	mkdir /etc/docker
	\cp ${workdir}/config/k8s/daemon.json /etc/docker
}
