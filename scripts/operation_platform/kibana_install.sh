#!/bin/bash
kibana_env_load(){
	tmp_dir=/tmp/kibana_tmp
	soft_name=kibana
	program_version=('5' '6' '7')
	url='https://mirrors.huaweicloud.com/kibana'
	select_version
	install_dir_set
	online_version
	

}

kibana_down(){
	if [[ ${os_bit} = '64' ]];then
		down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz'
	else
		down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86.tar.gz'
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

kibana_install_set(){
	input_option "输入http端口号" "5601" "kibana_port"
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
	sed -i "s/#server.port.*/server.port: ${kibana_port}/" ${conf_dir}/kibana.yml
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s%#elasticsearch.url.*%elasticsearch.url: ${elasticsearch_ip}%" ${conf_dir}/kibana.yml
	sed -i "s%##elasticsearch.hosts.*%elasticsearch.url: [${elasticsearch_ip}]%" ${conf_dir}/kibana.yml
	sed -i "s%#elasticsearch.requestTimeout:.*%elasticsearch.requestTimeout: 60000%" ${conf_dir}/kibana.yml
	sed -i "s%#i18n.locale:.*%i18n.locale: \"zh-CN\"%" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	User=kibana
	ExecStart="${home_dir}/bin/kibana"
	conf_system_service ${home_dir}/init
	add_system_service kibana ${home_dir}/init
}

kibana_install_ctl(){
	kibana_env_load
	kibana_install_set
	kibana_down
	kibana_install
	
}
