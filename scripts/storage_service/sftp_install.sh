#!/bin/bash
set -e

sftp_install_ctl(){
	add_sysuser
	input_option "请输入要SFTP家目录:" "/data/sftp" "sftp_dir"
	sftp_dir=${input_value}
	#set sftp homedir
	#创建数据目录
	mkdir -p ${sftp_dir}/${name}/upload
	#添加sftp用户组
	groupadd sftp>/dev/null 2>&1
	#修改用户家目录以及所属
	usermod -G sftp -d ${sftp_dir}/${name} -s /sbin/nologin ${name}>/dev/null 2>&1
	#将数据目录权限修改为用户
	chown -R ${name}.sftp ${sftp_dir}/${name}/upload
	sed -i 's[^Subsystem.*sftp.*/usr/libexec/openssh/sftp-server[#Subsystem	sftp	/usr/libexec/openssh/sftp-server[' /etc/ssh/sshd_config
	if [[ -z `grep -E '^ForceCommand    internal-sftp' /etc/ssh/sshd_config` ]];then
		cat >>/etc/ssh/sshd_config<<-EOF
		Subsystem       sftp    internal-sftp
		Match Group sftp
		ChrootDirectory %h
		ForceCommand    internal-sftp
		EOF
	fi
}
