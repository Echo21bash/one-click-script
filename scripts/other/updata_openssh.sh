#!/bin/bash

openssh_env_load(){
	tmp_dir=/usr/local/src/openssh_tmp
	mkdir -p ${tmp_dir}
	soft_name=openssh
	program_version=('8.4' '8.5' '8.6' '8.8')
	url='https://raw.githubusercontent.com/hebaodanroot/rpm_package'
	select_version

}


openssh_updata_set(){

	output_option '请选择升级方式' '本地 批量' 'deploy_mode'
	if [[ ${deploy_mode} = '2' ]];then
		vi ${workdir}/config/openssh/openssh-batch.conf
		. ${workdir}/config/openssh/openssh-batch.conf
	fi

}


openssh_down(){
	info_log "正在下载安装包"
	down_url="${url}/master/el${os_release}/openssh-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file
	
	down_url="${url}/master/el${os_release}/openssh-askpass-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file
	
	down_url="${url}/master/el${os_release}/openssh-askpass-gnome-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file
	
	down_url="${url}/master/el${os_release}/openssh-clients-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file

	down_url="${url}/master/el${os_release}/openssh-debuginfo-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file

	down_url="${url}/master/el${os_release}/openssh-server-${version_number}p1-1.el${os_release}.x86_64.rpm"
	online_down_file
	
}


openssh_local_run_telshell(){

	info_log "获取当前ssh版本"
	ssh_ver=`rpm -qa openssh | grep -oE "[0-9]{1}\.[0-9]{1}"`
	if [[ ${ssh_ver} > ${version_number} || ${ssh_ver} = ${version_number} ]];then
		info_log "现有版本大于等于选择版本无需升级"
		exit 0
	fi
	cp ${workdir}/bin/telshell ${tmp_dir}
	nohup ${tmp_dir}/telshell >/dev/null 2>&1 &
	if [[ -n `pidof telshell` ]];then
		info_log "telnet已经就绪，端口为1000。"
	else
		error_log "telnet未就绪，请检查！"
		exit 1
	fi
}


openssh_local_back(){
		
	info_log "备份openssh配置文件"
	if [[ ! -f /etc/pam.d/sshd_back_upgrade ]];then
		cp /etc/pam.d/sshd /etc/pam.d/sshd_back_upgrade
	fi
	if [[ ! -f /etc/ssh/sshd_config_back_upgrade ]];then
		cp /etc/ssh/sshd_config /etc/ssh/sshd_config_back_upgrade
	fi
}

openssh_local_upgrade(){

	info_log "正在升级sshd"
	yum install -y ${tmp_dir}/openssh*${version_number}*el${os_release}*.rpm
	if [[ $? = 0 ]];then
		cd /etc/ssh/
		chmod 400 ssh_host_ecdsa_key ssh_host_ed25519_key ssh_host_rsa_key
		cat /etc/pam.d/sshd_back_upgrade >/etc/pam.d/sshd
		cat	/etc/ssh/sshd_config_back_upgrade >/etc/ssh/sshd_config
		sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
		sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
		service_control sshd restart
	else
		error_log "安装rpm包失败，请检查！"
		exit 1
	fi
}

openssh_upgrade_batch(){

	info_log "正在向节点${now_host}分发ssh${service_id}安装程序"
	auto_input_keyword "
	ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-EOF
	mkdir -p ${tmp_dir}
	EOF
	scp -q -r -P ${ssh_port[$k]} ${tmp_dir}/openssh* ${workdir}/bin/telshell ${workdir}/scripts/public.sh ${host_ip[$k]}:${tmp_dir}
	ssh ${host_ip[$k]} -p ${ssh_port[$k]} <<-\"EOF\"
	. ${tmp_dir}/public.sh
	###获取当前ssh版本
	info_log "获取${now_host}当前ssh版本"
	ssh_ver=\`rpm -qa openssh | grep -oE \"[0-9]{1}\.[0-9]{1}\"\`
	if [[ \${ssh_ver} > ${version_number} || \${ssh_ver} = ${version_number} ]];then
		info_log "现有版本大于等于选择版本无需升级"
		exit 0
	fi
	
	###启动telnet
	info_log "启动telshell"
	nohup ${tmp_dir}/telshell >/dev/null 2>&1 &
	sleep 2
	if [[ -n \`pidof telshell\` ]];then
		info_log "telnet已经就绪，端口为1000。"
	else
		error_log "telnet未就绪，请检查！"
		exit 1
	fi
	###备份sshd
	info_log "备份${now_host}openssh配置文件"
	[[ ! -f /etc/pam.d/sshd_back_upgrade ]] && cp /etc/pam.d/sshd /etc/pam.d/sshd_back_upgrade
	[[ ! -f /etc/ssh/sshd_config_back_upgrade ]] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config_back_upgrade
	
	###升级sshd
	info_log "正在升级${now_host}sshd"
	yum install -y ${tmp_dir}/openssh*${version_number}*el${os_release}*.rpm
	if [[ \$? = 0 ]];then
		cd /etc/ssh/
		chmod 400 ssh_host_ecdsa_key ssh_host_ed25519_key ssh_host_rsa_key
		cat /etc/pam.d/sshd_back_upgrade >/etc/pam.d/sshd
		cat	/etc/ssh/sshd_config_back_upgrade >/etc/ssh/sshd_config
		sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
		sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
	else
		error_log "安装rpm包失败，请检查！"
		exit 1
	fi
	service_control sshd restart
	rm -rf ${tmp_dir}/public.sh
	EOF" "${passwd[$k]}"
}

openssh_upgrade(){

	if [[ ${deploy_mode} = '1' ]];then
		openssh_local_run_telshell
		openssh_local_back
		openssh_local_upgrade
	fi

	if [[ ${deploy_mode} = '2' ]];then
		local k=0
		for now_host in ${host_ip[@]}
		do
			openssh_upgrade_batch
			((k++))
		done

	fi

}

openssh_readme(){

	info_log "ssh升级完成，请尽快验证。如有问题可使用telnet连接修复。完成后请手动结束telshell进程"
}

updata_openssh_ctl(){
	openssh_env_load
	openssh_updata_set
	openssh_down
	openssh_upgrade
	openssh_readme
}
