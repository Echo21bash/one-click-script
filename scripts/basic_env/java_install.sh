#!/bin/bash
java_env_load(){
	tmp_dir=/tmp/java_tmp
	soft_name=java
	program_version=('7' '8')
	url='https://repo.huaweicloud.com/java/jdk'
	select_version
	online_version
	down_url="${url}/${detail_version_number}/jdk-${detail_version_number%-*}-linux-x64.tar.gz"
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

check_java(){
	#检查旧版本
	info_log "正在检查预装openjava..."
	j=`rpm -qa | grep  java | awk 'END{print NR}'`
	#卸载旧版
	if [ $j -gt 0 ];then
		info_log "java卸载清单:"
		for ((i=1;i<=j;i++));
		do		
			a1=`rpm -qa | grep java | awk '{if(NR == 1 ) print $0}'`
			echo $a1
			rpm -e --nodeps $a1
		done
		if [ $? = 0 ];then
			info_log "卸载openjava完成."
		else
			error_log "卸载openjava失败，请尝试手动卸载."
			exit 1
		fi
	else
		info_log "该系统没有预装openjava."
	fi
}

install_java(){

	home_dir=${install_dir}/java
	if [[ ${deploy_mode} = '1' ]];then
		mkdir -p ${home_dir}
		unpacking_file ${tmp_dir}/jdk-${detail_version_number%-*}-linux-x64.tar.gz ${tmp_dir}
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
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
			mkdir -p ${install_dir}/java
			mkdir -p ${tmp_dir}
			"
			info_log "正在向节点${now_host}分发java${service_id}安装程序和配置文件..."
			scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/${down_file_name} ${host_ip[$k]}:${tmp_dir}
			scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/java_profile.sh ${host_ip[$k]}:${tmp_dir}
			info_log "解压${down_file_name}..."
			ssh ${host_ip[$k]} -p ${ssh_port[$k]} "
			cd ${tmp_dir}
			tar --strip-components 1 zxf ${tmp_dir}/${down_file_name} -C ${install_dir}/java
			\cp ${tmp_dir}/java_profile.sh /etc/profile.d/
			chmod +x /etc/profile.d/java_profile.sh
			"
			((k++))
		done
	fi

}

java_install_ctl(){
	java_env_load
	java_install_set
	install_java
	clear_install
}