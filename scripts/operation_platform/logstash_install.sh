#!/bin/bash

logstash_env_load(){
	tmp_dir=/tmp/logstash_tmp
	soft_name=logstash
	program_version=('5' '6' '7')
	url='https://mirrors.huaweicloud.com/logstash'
	select_version
	install_dir_set
	online_version
	down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz'

}

logstash_down(){

	if [[ ${detail_version_number} > '7.10' ]];then
		down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz'
	else
		down_url='${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz'
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

logstash_install_set(){
echo
}

logstash_install(){
	home_dir=${install_dir}/logstash
	mkdir -p ${home_dir}/config.d
	mv ${tar_dir}/* ${home_dir}
	logstash_conf
	add_logstash_service
}

logstash_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
	sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
	sed -i "s%# path.config.*%path.config: ${home_dir}/config.d%" ${conf_dir}/logstash.yml
	sed -i "s%# http.host.*%http.host: \"${local_ip}\"%" ${conf_dir}/logstash.yml
	sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
	sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
}

add_logstash_service(){
	Type=simple
	ExecStart="${home_dir}/bin/logstash"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service ${home_dir}/init
	add_system_service logstash ${home_dir}/init
}

logstash_install_ctl(){
	logstash_env_load
	logstash_install_set
	logstash_down
	logstash_install
	
}
