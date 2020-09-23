#!/bin/bash

rancher_install_ctl(){
	if [[ -z `which dockerd 2>/dev/null` ]];then
		docker_install
	fi
	get_ip
	docker run -itd --name rancher --restart=unless-stopped \
	-p 8888:443 \
	-v /opt/rancher:/var/lib/rancher \
	rancher/rancher:latest
	if [[ $? = '0' ]];then
		sleep 10
		diy_echo "通过Docker部署完成，可通过https:${local_ip}:8888访问" "${info}"
	fi
}