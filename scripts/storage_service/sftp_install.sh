#!/bin/bash

sftp_install_ctl(){
	add_sysuser
	input_option "请输入要SFTP家目录:" "/data/sftp" "sftp_dir"
	sftp_dir=${input_value}
	#set sftp homedir
	mkdir -p ${sftp_dir}/${name}
	#父目录
	dname=$(dirname ${sftp_dir})
	groupadd sftp_group>/dev/null 2>&1
	usermod -G sftp_group -d ${dname} -s /sbin/nologin ${name}>/dev/null 2>&1
	chown -R ${name}.sftp_group ${sftp_dir}/${name}
	sed -i 's[^Subsystem.*sftp.*/usr/libexec/openssh/sftp-server[#Subsystem	sftp	/usr/libexec/openssh/sftp-server[' /etc/ssh/sshd_config
	if [[ -z `grep -E '^ForceCommand    internal-sftp' /etc/ssh/sshd_config` ]];then
		cat >>/etc/ssh/sshd_config<<-EOF
		Subsystem       sftp    internal-sftp
		Match Group sftp_group
		ChrootDirectory %h
		ForceCommand    internal-sftp
		EOF
	fi
}
