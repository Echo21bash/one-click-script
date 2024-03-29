#!/bin/bash

logstash_env_load(){
	tmp_dir=/usr/local/src/logstash_tmp
	soft_name=logstash
	program_version=('5' '6' '7')
	url='https://repo.huaweicloud.com/logstash'
	select_version
	install_dir_set
	online_version

}

logstash_down(){

	if [[ ${detail_version_number} > '7.10' ]];then
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}-linux-x86_64.tar.gz"
	else
		down_url="${url}/${detail_version_number}/${soft_name}-${detail_version_number}.tar.gz"
	fi
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

logstash_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/elk/logstash-single.conf
		. ${workdir}/config/elk/logstash-single.conf
	fi
	if [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/elk/logstash-batch.conf
		. ${workdir}/config/elk/logstash-batch.conf
	fi
}

logstash_run_env_check(){

	if [[ ${deploy_mode} = '1' ]];then
		java_status=`${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && echo javaok`
		if [[ ${java_status} = "javaok" ]];then
			success_log "java运行环境已就绪"
		else
			error_log "java运行环境未就绪"
			exit 1
		fi
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local k=0
		for now_host in ${host_ip[@]}
		do
			###检测JDK环境
			java_status=`auto_input_keyword "ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			${JAVA_HOME}/bin/java -version > /dev/null 2>&1  && echo javaok
			EOF" "${passwd[$k]}"`
			if [[ ${java_status} =~ "javaok" ]];then
				success_log "主机${host_ip[$k]}java运行环境已就绪"
			else
				error_log "主机${host_ip[$k]}java运行环境未就绪"
				exit 1
			fi
		done
	fi
}

logstash_install(){
	if [[ ${deploy_mode} = '1' ]];then
		logstash_run_env_check
		logstash_down
		home_dir=${install_dir}/logstash
		mkdir -p ${home_dir}/config.d
		useradd -M logstash
		mv ${tar_dir}/* ${home_dir}
		chown -R logstash.logstash ${home_dir}
		logstash_conf
		add_logstash_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		logstash_run_env_check
		logstash_down
		home_dir=${install_dir}/logstash
		logstash_conf
		local i=1
		local k=0
		for now_host in ${host_ip[@]}
		do
			info_log "正在向节点${now_host}分发logstash安装程序和配置文件..."
			auto_input_keyword "
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			useradd -M logstash
			mkdir -p ${install_dir}/logstash
			EOF
			scp -q -r -P ${ssh_port[$k]} ${tar_dir}/* ${host_ip[$k]}:${install_dir}/logstash
			scp -q -r -P ${ssh_port[$k]} ${workdir}/scripts/public.sh ${host_ip[$k]}:/tmp
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			. /tmp/public.sh
			chown -R logstash.logstash ${install_dir}/logstash
			Type=simple
			User=logstash
			ExecStart="${home_dir}/bin/logstash"
			Environment="JAVA_HOME=${JAVA_HOME}"
			SuccessExitStatus="143"
			add_daemon_file ${home_dir}/logstash.service
			add_system_service logstash ${home_dir}/logstash.service
			service_control logstash restart
			rm -rf /tmp/public.sh
			EOF" "${passwd[$k]}"
			((k++))
		done
	fi
}

logstash_conf(){
	if [[ ${deploy_mode} = '1' ]];then
		get_ip
		conf_dir=${home_dir}/config
		\cp ${workdir}/config/elk/logstash-http.conf ${home_dir}/config.d/
		if [[ ! -f ${conf_dir}/logstash.yml.bak ]];then
			cp ${conf_dir}/logstash.yml ${conf_dir}/logstash.yml.bak
		fi
		sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
		sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
		sed -i "s%# path.config.*%path.config: ${home_dir}/config.d%" ${conf_dir}/logstash.yml
		sed -i "s%# http.host.*%http.host: \"${local_ip}\"%" ${conf_dir}/logstash.yml
		sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
		if [[ ${input_type} = 'kafka' && ${output_type} = 'elasticsearch' ]];then
			\cp ${workdir}/config/elk/logstash-kafka2es.conf ${home_dir}/config.d/
			sed -i "s/bootstrap_servers => .*/bootstrap_servers => '${input_kafka_url}'/" ${home_dir}/config.d/logstash-kafka2es.conf
			sed -i "s/topics_pattern => .*/topics_pattern => '${topics_pattern}-.*'/" ${home_dir}/config.d/logstash-kafka2es.conf
			sed -i "s/hosts => .*/hosts => [${output_es_url}]/" ${home_dir}/config.d/logstash-kafka2es.conf
			if [[ -n ${output_es_name} && -n ${output_es_passwd} ]];then
				sed -i "s/#user => .*/user => '${output_es_name}'/" ${home_dir}/config.d/logstash-kafka2es.conf
				sed -i "s/#password => .*/password => '${output_es_passwd}'/" ${home_dir}/config.d/logstash-kafka2es.conf
			fi
		fi
	fi
	if [[ ${deploy_mode} = '2' ]];then
		mkdir -p ${tar_dir}/config.d/
		conf_dir=${tar_dir}/config
		\cp ${workdir}/config/elk/logstash-http.conf ${tar_dir}/config.d/
		if [[ ! -f ${conf_dir}/logstash.yml.bak ]];then
			cp ${conf_dir}/logstash.yml ${conf_dir}/logstash.yml.bak
		fi
		sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
		sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 4/" ${conf_dir}/logstash.yml
		sed -i "s%# path.config.*%path.config: ${home_dir}/config.d%" ${conf_dir}/logstash.yml
		sed -i "s/-Xms.*/-Xms${jvm_heap}/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx${jvm_heap}/" ${conf_dir}/jvm.options
		if [[ ${input_type} = 'kafka' && ${output_type} = 'elasticsearch' ]];then
			\cp ${workdir}/config/elk/logstash-kafka2es.conf ${tar_dir}/config.d/
			sed -i "s/bootstrap_servers => .*/bootstrap_servers => '${input_kafka_url}'/" ${tar_dir}/config.d//logstash-kafka2es.conf
			sed -i "s/topics_pattern => .*/topics_pattern => '${topics_pattern}-.*'/" ${tar_dir}/config.d/logstash-kafka2es.conf
			sed -i "s/hosts => .*/hosts => [${output_es_url}]/" ${tar_dir}/config.d/logstash-kafka2es.conf
			if [[ -n ${output_es_name} && -n ${output_es_passwd} ]];then
				sed -i "s/#user => .*/user => '${output_es_name}'/" ${tar_dir}/config.d/logstash-kafka2es.conf
				sed -i "s/#password => .*/password => '${output_es_passwd}'/" ${tar_dir}/config.d/logstash-kafka2es.conf
			fi
		fi
	fi
}

add_logstash_service(){

	if [[ ${deploy_mode} = '1' ]];then
		Type=simple
		User=logstash
		ExecStart="${home_dir}/bin/logstash"
		Environment="JAVA_HOME=${JAVA_HOME}"
		SuccessExitStatus="143"
		add_daemon_file ${home_dir}/logstash.service
		add_system_service logstash ${home_dir}/logstash.service
		service_control logstash restart
	fi
}

logstash_readme(){
	info_log "logstash已经安装完成。"
}

logstash_install_ctl(){
	logstash_env_load
	logstash_install_set
	logstash_install
	logstash_readme
}
