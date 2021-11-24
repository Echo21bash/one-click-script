#!/bin/bash

java_env_load(){
	tmp_dir=/usr/local/src/java_tmp
	soft_name=java
	program_version=('7' '8' '9' '10' '11')
	url='https://repo.huaweicloud.com/java/jdk'
	select_version
	online_version

}

java_down(){
	if [[ ${version_number} -lt '9' ]];then
		down_url="${url}/${detail_version_number}/jdk-${detail_version_number%-*}-linux-x64.tar.gz"
	else
		down_url="${url}/${detail_version_number}/jdk-${detail_version_number%+*}_linux-x64_bin.tar.gz"
	fi
	online_down_file
}

java_install_set(){

	output_option '请选择安装模式' '本机安装 批量安装' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		install_dir_set
	elif [[ ${deploy_mode} = '2' ]];then
		install_dir_set
		vi ${workdir}/config/java/java.conf
		. ${workdir}/config/java/java.conf
	fi
	
}


java_install(){

	home_dir=${install_dir}/java
	if [[ ${deploy_mode} = '1' ]];then
		mkdir -p ${home_dir}
		unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
		cp -rp ${tar_dir}/* ${home_dir}
		\cp ${workdir}/config/java/java_profile.sh /etc/profile.d/
		chmod +x /etc/profile.d/java_profile.sh
		sed -i "s%JAVA_HOME=.*%JAVA_HOME=${home_dir}%" /etc/profile.d/java_profile.sh
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
		\cp ${workdir}/config/java/java_profile.sh ${tmp_dir}
		sed -i "s%JAVA_HOME=.*%JAVA_HOME=${home_dir}%" ${tmp_dir}/java_profile.sh
		local k=0
		for now_host in ${host_ip[@]}
		do
			info_log "正在向节点${now_host}分发java${service_id}安装程序和配置文件..."
			auto_input_keyword "
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			mkdir -p ${install_dir}/java
			mkdir -p ${tmp_dir}
			EOF
			scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/${down_file_name} ${host_ip[$k]}:${tmp_dir}
			scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/java_profile.sh ${host_ip[$k]}:${tmp_dir}
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
			cd ${tmp_dir}
			tar zxf ${tmp_dir}/${down_file_name} -C ${install_dir}/java --strip-components 1 
			\cp ${tmp_dir}/java_profile.sh /etc/profile.d/
			chmod +x /etc/profile.d/java_profile.sh
			EOF" "${passwd[$k]}"
			((k++))
		done
	fi

}

java_readme(){

	success_log "java运行环境已就绪"
}

java_install_ctl(){
	java_env_load
	java_install_set
	java_down
	java_install
	java_readme
	
}