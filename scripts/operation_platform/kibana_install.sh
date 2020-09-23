#!/bin/bash

kibana_install_set(){
	input_option "输入http端口号" "5601" "kibana_port"
	input_option "输入elasticsearch服务http地址" "127.0.0.1:9200" "elasticsearch_ip"
	elasticsearch_ip=${input_value}
}

kibana_install(){
	
	mv ${tar_dir}/* ${home_dir}
	kibana_conf
	add_kibana_service
}

kibana_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/#server.port.*/server.port: ${kibana_port}/" ${conf_dir}/kibana.yml
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s@#elasticsearch.url.*@elasticsearch.url: http://${elasticsearch_ip}@" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	ExecStart="${home_dir}/bin/kibana"
	conf_system_service 
	add_system_service kibana ${home_dir}/kibana_init
}

kibana_install_ctl(){
	install_version kibana
	install_selcet
	kibana_install_set
	install_dir_set
	download_unzip
	kibana_install
	clear_install
}
