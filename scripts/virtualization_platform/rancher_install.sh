#!/bin/bash

rancher_install_ctl(){
	input_option "请输入访问端口" "8888" "port"
	input_option "请输入数据存储路径" "/opt/rancher" "data_dir"
	data_dir=${input_value}
	if [[ -z `which dockerd 2>/dev/null` ]];then
		docker_install
	fi
	info_log "正在拉取镜像..."
	docker pull rancher/rancher:latest
	get_ip
	if [[ -d ${data_dir} ]];then
		mkdir -p ${data_dir}
	fi
	docker run -itd --name rancher --restart=unless-stopped \
	-p ${port}:443 \
	-v ${data_dir}:/var/lib/rancher \
	rancher/rancher:latest
	info_log "正在启动容器..."
	sleep 40
	http_code=`curl -sILk -w %{http_code} -o /dev/null https://${local_ip}:${port}`
	if [[ ${http_code} = '200' ]];then
		info_log "通过Docker部署完成，可通过https://${local_ip}:${port}访问"
	else
		sleep 40
		http_code=`curl -sILk -w %{http_code} -o /dev/null https://${local_ip}:${port}`
		if [[ ${http_code} = '200' ]];then
			info_log "通过Docker部署完成，可通过https://${local_ip}:${port}访问"
		else
			error_log "容器启动失败,请通过docker logs rancher命令查看启动日志"
		fi
	fi
}