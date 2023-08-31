#!/bin/bash

docker_install_ctl(){

	if [[ -n `which dockerd 2>/dev/null` ]];then
		diy_echo "检测到已经安装了docker请检查..." "${yellow}" "${warning}"
	else
		if [[ ${os_release} < "7" ]];then
			yum install -y docker
		else
			down_file http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
			yum install -y docker-ce
		fi
		mkdir /etc/docker
		\cp ${workdir}/config/docker/daemon.json /etc/docker
	fi
	
	if [[ -z `which docker-compose 2>/dev/null` ]];then
		down_file https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
		chmod +x /usr/local/bin/docker-compose
	fi
}
