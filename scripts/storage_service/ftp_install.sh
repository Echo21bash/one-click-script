#!/bin/bash

ftp_install_set(){
	input_option '是否快速配置vsftp服务' 'y' 'vsftp'
	vsftp=${input_value}
	yes_or_no ${vsftp}
	if [[ $? = 1 ]];then
		diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
	fi
	if [[ -n `ps aux | grep vsftp | grep -v grep` || -d /etc/vsftpd ]];then
		diy_echo "vsftp正在运行中,或者已经安装vsftp!!" "${yellow}" "${warning}"
		input_option '确定要重新配置vsftp吗?' 'y' 'continue'
		continue=${input_value}
		yes_or_no ${continue}
		if [[ $? = 1 ]];then
			diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
		fi
	fi
	input_option '设置ftp默认文件夹' '/data/ftp' 'ftp_dir'
	ftp_dir=${input_value[@]}

	if [[ ! -d ${ftp_dir} ]];then
		mkdir -p ${ftp_dir}  
	fi
	diy_echo "正在配置VSFTP用户,有管理员和普通用户两种角色,管理员有完全权限,普通用户只有上传和下载的权限." "" "${info}"
	input_option '输入管理员用户名' 'admin' 'manager'
	manager=${input_value}
	input_option '输入管理员密码' 'admin' 'manager_passwd'
	manager_passwd=${input_value}
	input_option '输入普通用户用户名' 'user' 'user'
	user=${input_value}
	input_option '输入普通用户密码' 'user' 'user_passwd'
	user_passwd=${input_value}
}

ftp_install(){
	diy_echo "正在安装db包..." "" "${info}"
	if [[ ${os_release} < '7' ]];then
		yum install -y db4-utils
	else
		yum install -y libdb-utils
	fi
	yum install -y vsftpd

}

ftp_config(){
	diy_echo "正在配置vsftp..." "" "${info}"
	id ftp > /dev/null 2>&1
	if [[ $? = '1' ]];then
		useradd -s /sbin/nologin ftp >/dev/null
		usermod -G ftp -d /var/ftp -s /sbin/nologin
	fi
	mkdir -p /etc/vsftpd/vsftpd.conf.d
	cat >/etc/vsftpd/vftpusers<<-EOF
	${manager}
	${manager_passwd}
	${user}
	${user_passwd}
	EOF

	chown -R ftp.ftp ${ftp_dir}
	db_load -T -t hash -f /etc/vsftpd/vftpusers /etc/vsftpd/vftpusers.db
	
	if [[ ! -f /etc/vsftpd/vsftpd.conf.bak ]];then
		mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
	fi

	\cp -rp ${workdir}/config/vsftp/vsftpd.conf /etc/vsftpd/vsftpd.conf
	sed -i "s?anon_root=.*?anon_root=${ftp_dir}?" /etc/vsftpd/vsftpd.conf
	sed -i "s?local_root=.*?local_root=${ftp_dir}?" /etc/vsftpd/vsftpd.conf
	
	\cp -rp ${workdir}/config/vsftp/admin.conf /etc/vsftpd/vsftpd.conf.d/${manager}

	cat >/etc/pam.d/vsftpd.vuser<<-EOF
	auth required pam_userdb.so db=/etc/vsftpd/vftpusers
	account required pam_userdb.so db=/etc/vsftpd/vftpusers
	EOF

}

ftp_install_ctl(){
	ftp_install_set
	ftp_install
	ftp_config
	service_control vsftpd.service start
}
