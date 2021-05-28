#!/bin/bash
openssh_env_load(){
	tmp_dir=/tmp/openssh_tmp
	mkdir -p ${tmp_dir}
	soft_name=openssh
	program_version=('8.4' '8.5' '8.6')
	url='https://github.com/hebaodanroot/rpm_package'
	select_version

	ssh_ver=`rpm -qa openssh | grep -oE "[0-9]{1}\.[0-9]{1}"`
	if [[ ${ssh_ver} -gt ${detail_version_number} ]];then
		info_log "无需升级"
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
	down_url="${url}/raw/master/el${os_release}/openssh-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file
	
	down_url="${url}/raw/master/el${os_release}/openssh-askpass-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file
	
	down_url="${url}/raw/master/el${os_release}/openssh-askpass-gnome-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file
	
	down_url="${url}/raw/master/el${os_release}/openssh-clients-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file

	down_url="${url}/raw/master/el${os_release}/openssh-debuginfo-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file

	down_url="${url}/raw/master/el${os_release}/openssh-server-${detail_version_number}p1-1.el${os_release}.centos.x86_64.rpm"
	online_down_file
	
}

openssh_updata(){

	info_log "正在安装"
	rpm -Uvh ${tmp_dir}/openssh*${detail_version_number}*el${os_release}*.rpm
	if [[ $? = 0 ]];then
		cd /etc/ssh/
		chmod 400 ssh_host_ecdsa_key ssh_host_ed25519_key ssh_host_rsa_key
		cat /etc/pam.d/sshd-bak >/etc/pam.d/sshd
		cat	/etc/ssh/sshd_config-bak >/etc/ssh/sshd_config
		success_log "升级完成请重启sshd服务验证"
	fi
}


updata_openssh_ctl(){
	openssh_env_load
	openssh_bak
	openssh_down
	openssh_updata
}
