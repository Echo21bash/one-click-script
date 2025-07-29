#!/bin/bash

sftp_install_set(){
	get_ip
	output_option "请选择实现方式" "基于sshd sftpgo" "install_mode"
	if [[ ${install_mode} = '1' ]];then
		sftp_install_sshd
	elif [[ ${install_mode} = '2' ]];then
		sftp_install_sftpgo
		vi ${workdir}/config/sftp/sftpgo.conf
		. ${workdir}/config/sftp/sftpgo.conf
	fi
}

sftp_install_sshd(){
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
	sftp_install_sshd_config
	service_control sshd restart
}

sftp_install_sshd_config(){

	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +"%Y-%m-%dT%H:%M:%S")
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

sftp_install_sftpgo_env_load(){
	soft_name=sftpgo
	tmp_dir=/usr/local/src/sftpgo_tmp
	mkdir -p ${tmp_dir}
	program_version=('2.6')
	url='https://github.com/drakkan/sftpgo'
	select_version
	install_dir_set
	online_version
}

sftpgo_down(){

	down_url="${url}/releases/download/v${detail_version_number}/sftpgo_v${detail_version_number}_linux_x86_64.tar.xz"
	online_down_file
	unpacking_file sftpgo_v${detail_version_number}_linux_x86_64.tar.xz ${tmp_dir}

}

sftpgo_config(){
	sed -i "s/8080/${sftp_webui_port}/" ${home_dir}/etc/sftpgo.json
	sed -i "s/2022/${sftpd_port}/" ${home_dir}/etc/sftpgo.json
	sed -i "s/587/${smtp_port}/" ${home_dir}/etc/sftpgo.json
}

add_sftpgo_service(){
	
	Type=simple
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/bin/sftpgo serve --config-dir=${home_dir}/etc"
	add_daemon_file ${home_dir}/sftpgo.service
	add_system_service sftpgo ${home_dir}/sftpgo.service
	service_control sftpgo restart
	
}

sftp_install_sftpgo(){
	sftp_install_sftpgo_env_load
	sftpgo_down
	home_dir=${install_dir}/sftpgo
	mkdir -p ${home_dir}/{bin,etc,logs}

	cp ${tmp_dir}/sftpgo ${home_dir}/bin/sftpgo
	cp ${tmp_dir}/sftpgo.json ${home_dir}/etc/sftpgo.json
	sftpgo_config
	add_sftpgo_service
	
}

sftp_use(){
	if [[ ${install_mode} = '1' ]];then
		info_log "使用sshd端口连接sftp服务即可，账号密码为系统用户${name}的账号密码；
		添加新的sftp账号命令：
		1.useradd sftpsuer;
		2.echo \"passwd\" | passwd --stdin sftpsuer;
		3.mkdir -p ${sftp_dir}/sftpsuer/upload;
		4.usermod -G sftp -d ${sftp_dir}/sftpsuer -s /sbin/nologin sftpsuer;
		5.chown -R sftpsuer.sftp ${sftp_dir}/sftpsuer/upload;
		6.systemctl restart sshd;"
	elif [[ ${install_mode} = '2' ]];then
		info_log "通过http://${local_ip}:${sftp_webui_port}设置sftp服务"
	fi
}

sftp_install_ctl(){
	sftp_install_set
	sftp_use
}
