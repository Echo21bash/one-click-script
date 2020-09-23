#!/bin/bash

logstash_install_set(){
echo
}

logstash_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/config.d
	logstash_conf
	add_logstash_service
}

logstash_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
	sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
	sed -i "s@# path.config.*@path.config: ${home_dir}/config.d@" ${conf_dir}/logstash.yml
	sed -i "s/# http.host.*/http.host: \"${local_ip}\" " ${conf_dir}/logstash.yml
	sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
	sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
}

add_logstash_service(){
	Type=simple
	ExecStart="${home_dir}/bin/logstash"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service logstash ${home_dir}/init
}

logstash_install_ctl(){
	install_version logstash
	install_selcet
	logstash_install_set
	install_dir_set
	download_unzip
	logstash_install
	clear_install
}
