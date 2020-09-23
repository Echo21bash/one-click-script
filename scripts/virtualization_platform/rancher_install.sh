#!/bin/bash

rancher_install_ctl(){
	if [[ -z `which dockerd 2>/dev/null` ]];then
		docker_install
	fi
	docker run -itd --name rancher --restart=unless-stopped \
	-p 8888:80 \
	-v /opt/rancher:/var/lib/rancher \
	rancher/rancher:latest
}