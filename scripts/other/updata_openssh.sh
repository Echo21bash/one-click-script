#!/bin/bash

openssh_env_load(){
	tmp_dir=/usr/local/src/openssh_tmp
	mkdir -p ${tmp_dir}
	soft_name=openssh
	program_version=('8.4' '8.5' '8.6')
	url='https://raw.githubusercontent.com/hebaodanroot/rpm_package'
	select_version
	ssh_ver=`rpm -qa openssh | grep -oE "[0-9]{1}\.[0-9]{1}"`
	if [[ ${ssh_ver} > ${version_number} ]];then
		info_log "现有版本大于选择版本无需升级"
		exit 0
	fi
}

openssh_bak(){
	info_log "备份openssh配置文件"
	if [[ ! -f /etc/pam.d/sshd-bak ]];then
		cp /etc/pam.d/sshd /etc/pam.d/sshd-bak
	fi
	if [[ ! -f /etc/ssh/sshd_config-bak ]];then
		cp /etc/ssh/sshd_config /etc/ssh/sshd_config-bak
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

openssh_updata(){

	info_log "正在安装"
	yum install -y ${tmp_dir}/openssh*${version_number}*el${os_release}*.rpm
	if [[ $? = 0 ]];then
		cd /etc/ssh/
		chmod 400 ssh_host_ecdsa_key ssh_host_ed25519_key ssh_host_rsa_key
		cat /etc/pam.d/sshd-bak >/etc/pam.d/sshd
		cat	/etc/ssh/sshd_config-bak >/etc/ssh/sshd_config
		sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
		sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
		success_log "升级完成请重启sshd服务验证"
	fi
}


updata_openssh_ctl(){
	openssh_env_load
	openssh_bak
	openssh_down
	openssh_updata
}
