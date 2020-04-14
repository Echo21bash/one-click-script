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
	manager=${input_value[@]}
	input_option '输入管理员密码' 'admin' 'manager_passwd'
	manager_passwd=${input_value[@]}
	input_option '输入普通用户用户名' 'user' 'user'
	user=${input_value[@]}
	input_option '输入普通用户密码' 'user' 'user_passwd'
	user_passwd=${input_value[@]}
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

	cat >/etc/vsftpd/vsftpd.conf<<-EOF
	# Example config file /etc/vsftpd/vsftpd.conf
	#
	# The default compiled in settings are fairly paranoid. This sample file
	# loosens things up a bit, to make the ftp daemon more usable.
	# Please see vsftpd.conf.5 for all compiled in defaults.
	#
	# READ THIS: This example file is NOT an exhaustive list of vsftpd options.
	# Please read the vsftpd.conf.5 manual page to get a full idea of vsftpd's
	# capabilities.

	#禁止匿名登陆
	anonymous_enable=NO
	anon_root=${ftp_dir}
	anon_umask=022
	#普通用户只有上传下载权限
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	local_enable=YES
	#指定ftp路径
	local_root=${ftp_dir}

	local_umask=022
	connect_from_port_20=YES
	allow_writeable_chroot=YES
	reverse_lookup_enable=NO
	xferlog_enable=YES


	#开启ASCII模式传输数据
	ascii_upload_enable=YES
	ascii_download_enable=YES

	ftpd_banner=Welcome to blah FTP service.
	listen=YES
	userlist_enable=YES
	tcp_wrappers=YES

	#开启虚拟账号
	guest_enable=YES
	guest_username=ftp
	pam_service_name=vsftpd.vuser
	user_config_dir=/etc/vsftpd/vsftpd.conf.d

	#开启被动模式
	pasv_enable=YES
	pasv_min_port=40000
	pasv_max_port=40100
	EOF

	cat >/etc/vsftpd/vsftpd.conf.d/${manager}<<-EOF
	anon_umask=022
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	anon_other_write_enable=YES
	EOF

	cat >/etc/pam.d/vsftpd.vuser<<-EOF
	auth required pam_userdb.so db=/etc/vsftpd/vftpusers
	account required pam_userdb.so db=/etc/vsftpd/vftpusers
	EOF

}

ftp_install_ctl(){
	ftp_install_set
	ftp_install
	ftp_config
	service_control vsftpd.service
}

minio_install_set(){
	output_option "请选择安装模式" "单机模式 集群模式" "deploy_mode"
	input_option "请输入minio端口" "9000" "minio_port"
	input_option "请输入minio存储路径" "/data/minio" "data_dir"
	data_dir=${input_value}
	input_option "请输入minio账号key(>=3位)" "minio" "minio_access"
	minio_access=${input_value}
	input_option "请输入minio认证key(8-40位)" "12345678" "minio_secret"
	minio_secret=${input_value}
}

minio_config(){
	mkdir -p ${home_dir}/{bin,etc}
	mkdir -p ${data_dir}
	mv ${install_dir}/minio-release ${home_dir}/bin/minio
	chmod +x ${home_dir}/bin/minio
	cat >${home_dir}/etc/minio<<-EOF
	MINIO_ACCESS_KEY=${minio_access}
	MINIO_SECRET_KEY=${minio_secret}
	MINIO_VOLUMES=${data_dir}
	MINIO_OPTS="-C ${home_dir}/etc --address :${minio_port}"
	EOF
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_minio_service(){
	EnvironmentFile="${home_dir}/etc/minio"
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES"
	#ARGS="&"
	conf_system_service
	add_system_service minio ${home_dir}/init
}

minio_install_ctl(){
	install_selcet
	minio_install_set
	install_dir_set minio
	download_unzip
	minio_config
	add_minio_service
	service_control minio
}

fastdfs_install_set(){
	
	input_option '请输入文件存储路径' '/data/fdfs' 'file_dir'
	file_dir=${input_value}
	diy_echo "配置tracker服务" "${yellow}" "${info}"
	input_option '请输入tracker端口' '22122' 'tracker_port'
	diy_echo "配置storage服务" "${yellow}" "${info}"
	input_option '请输入storage端口' '23000' 'storage_port'
	input_option '请输入tracker_server地址(多个空格隔开)' '127.0.0.1:22122' 'tracker_ip'
	tracker_ip=(${input_value[@]})
	input_option '是否开启fastdht' 'n' 'fastdht'
	fastdht=${input_value}
	yes_or_no ${fastdht}
	if [[ $? = 0 ]];then
		input_option '请输入fastdht地址(多个空格隔开)' '127.0.0.1:11411' 'fastdht_ip'
		fastdht_ip=(${input_value[@]})
		fastdht=y
	fi
	input_option '是否安装fastdht' 'y' 'install_fastdht'
	install_fastdht=${input_value}
	yes_or_no ${install_fastdht}
	if [[ $? = 0 ]];then
		input_option '请输入fastdht端口' '11411' 'fastdht_port'
		install_fastdht=y
	fi

}

fastdfs_install(){
	yum install gcc -y
	cd ${tar_dir}
	diy_echo "正在安装相关依赖..." "" "${info}"
	wget https://codeload.github.com/happyfish100/libfastcommon/tar.gz/master -O libfastcommon-master.tar.gz && tar -zxf libfastcommon-master.tar.gz
	cd libfastcommon-master
	#libfastcommon安装目录配置
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	./make.sh  && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "libfastcommon安装完成." "" "${info}"
	else
		diy_echo "libfastcommon安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastcommon /usr/include
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib/libfastcommon.so
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib64/libfastcommon.so
	#fastdfs安装目录配置
	cd ${tar_dir}
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
	sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh

	diy_echo "正在安装fastdfs服务..." "" "${info}"
	./make.sh && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "fastdfs安装完成." "" "${info}"
	else
		diy_echo "fastdfs安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastdfs /usr/include
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib/libfdfsclient.so
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib64/libfdfsclient.so
	
	if [[ ${install_fastdht} = 'y' ]];then
		wget https://codeload.github.com/hebaodanroot/fastdht/tar.gz/patch-1 -O fastdht-patch-1.tar.gz && tar -zxf fastdht-patch-1.tar.gz
		cd fastdht-patch-1
		#fastdht安装目录配置
		sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
		sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
		sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
		sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh
		./make.sh && ./make.sh install
		if [[ $? = '0' ]];then
			diy_echo "fastdht安装完成." "" "${info}"
		else
			diy_echo "fastdht安装失败." "${yellow}" "${error}"
			exit
		fi
	fi
}

fastdfs_config(){
	mkdir -p ${file_dir}
	cp ${home_dir}/etc/tracker.conf.sample ${home_dir}/etc/tracker.conf
	cp ${home_dir}/etc/storage.conf.sample ${home_dir}/etc/storage.conf
	cp ${home_dir}/etc/client.conf.sample ${home_dir}/etc/client.conf
	cp ${tar_dir}/conf/http.conf ${home_dir}/etc
	cp ${tar_dir}/conf/mime.types ${home_dir}/etc
	cp ${workdir}/conf/fastdfs_start.sh ${home_dir}/bin/start.sh && chmod +x ${home_dir}/bin/start.sh
	get_ip

	sed -i "s#^base_path.*#base_path=${file_dir}#" ${home_dir}/etc/client.conf
	sed -i "s#^tracker_server.*#tracker_server=${local_ip}:${tracker_port}#" ${home_dir}/etc/client.conf


	sed -i "s#^port.*#port=${tracker_port}#" ${home_dir}/etc/tracker.conf
	sed -i "s#^base_path.*#base_path=${file_dir}#" ${home_dir}/etc/tracker.conf
	
	sed -i "s#^port.*#port=${storage_port}#" ${home_dir}/etc/storage.conf
	sed -i "s#^base_path.*#base_path=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#^store_path0.*#store_path0=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#^tracker_server.*#\#tracker_server=127.0.0.1:22122#" ${home_dir}/etc/storage.conf
	#配置多个tracker_ip
	len=${#fastdht_ip[@]}
	for ((i=0;i<$len;i++))
	do
		sed -i "/#standard log/itracker_server=${tracker_ip[$i]}" ${home_dir}/etc/storage.conf
	done
	

	if [[ ${fastdht} = 'y' ]];then
		sed -i "s#^check_file_duplicate.*#check_file_duplicate=1#" ${home_dir}/etc/storage.conf
		sed -i "/##include /home/yuqing/fastdht/a#include ${home_dir}/etc/fdht_servers.conf" ${home_dir}/etc/storage.conf
		#配置多个fdht_servers
		len=${#fastdht_ip[@]}
		echo "group_count = ${len}">${home_dir}/etc/fdht_servers.conf
		for ((i=0;i<$len;i++))
		do
			echo "group0 = ${fastdht_ip[$i]}">>${home_dir}/etc/fdht_servers.conf
		done
	fi

	if [[ ${install_fastdht} = 'y' ]];then
		sed -i "s#^port.*#port=${fastdht_port}#" ${home_dir}/etc/fdhtd.conf
		sed -i "s#^base_path.*#base_path=${file_dir}#" ${home_dir}/etc/fdhtd.conf
	fi
	add_log_cut fastdfs ${file_dir}/logs/*.log
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_fastdfs_service(){
	
	Type="forking"
	ExecStart="${home_dir}/bin/start.sh fdfs_trackerd"
	PIDFile="${file_dir}/data/fdfs_trackerd.pid"
	conf_system_service
	add_system_service fdfs_trackerd ${home_dir}/init

	ExecStart="${home_dir}/bin/start.sh fdfs_storaged"
	PIDFile="${file_dir}/data/fdfs_storaged.pid"
	conf_system_service
	add_system_service fdfs_storaged ${home_dir}/init

	if [[ ${install_fastdht} = 'y' ]];then
		ExecStart="${home_dir}/bin/start.sh fdhtd"
		PIDFile="${file_dir}/data/fdhtd.pid.pid"
		conf_system_service
		add_system_service fdhtd ${home_dir}/init
	fi
}

fastdfs_install_ctl(){
	install_selcet
	fastdfs_install_set
	install_dir_set fastdfs
	download_unzip 
	fastdfs_install
	fastdfs_config
	add_fastdfs_service
	clear_install
}

nfs_install_ctl(){
	input_option "请输入要共享的目录:" "/data/nfs" "nfs_dir"
	nfs_dir=${input_value}
	yum install -y nfs-utils
	cat >>/etc/exports<<-EOF
	${nfs_dir} *(rw,sync)
	EOF
	[[ -d ${nfs_dir} ]] && mkdir -p ${nfs_dir}
	start_arg='y'
	service_control nfs
}