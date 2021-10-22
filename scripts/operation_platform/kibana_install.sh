#!/bin/bash

kibana_env_load(){
	tmp_dir=/usr/local/src/kibana_tmp
	soft_name=kibana
	program_version=('5' '6' '7')
	url='https://repo.huaweicloud.com/kibana'
	select_version
	install_dir_set
	online_version
	

}

kibana_down(){
	if [[ ${os_bit} = '64' ]];then
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz"
	else
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86.tar.gz"
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

kibana_install_set(){
	input_option "输入elasticsearch服务http地址" "http://127.0.0.1:9200,http://127.0.0.1:9200,http://127.0.0.1:9200" "elasticsearch_ip"
	elasticsearch_ip=${input_value}
}

kibana_install(){
	home_dir=${install_dir}/kibana
	mkdir -p ${install_dir}/kibana
	useradd kibana
	mv ${tar_dir}/* ${home_dir}
	chown -R kibana.kibana ${home_dir}
	kibana_conf
	add_kibana_service
}

kibana_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s%#elasticsearch.url.*%elasticsearch.url: ${elasticsearch_ip}%" ${conf_dir}/kibana.yml
	sed -i "s%#elasticsearch.hosts.*%elasticsearch.hosts: [${elasticsearch_ip}]%" ${conf_dir}/kibana.yml
	sed -i "s%#elasticsearch.requestTimeout:.*%elasticsearch.requestTimeout: 60000%" ${conf_dir}/kibana.yml
	sed -i "s%#i18n.locale:.*%i18n.locale: \"zh-CN\"%" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	User=kibana
	ExecStart="${home_dir}/bin/kibana"
	add_daemon_file ${home_dir}/kibana.service
	add_system_service kibana ${home_dir}/kibana.service
	service_control kibana enable
	service_control kibana restart
}

kibana_readme(){

	info_log "安装完成访问地址是http://${local_ip}:5601"
}

kibana_install_ctl(){
	kibana_env_load
	kibana_install_set
	kibana_down
	kibana_install
	kibana_readme
	
}
