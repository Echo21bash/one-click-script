#!/bin/bash

fastdfs_env_load(){
	tmp_dir=/usr/local/src/fastdfs_tmp
	mkdir -p ${tmp_dir}
	soft_name=fastdfs
	program_version=('5' '6')
	url='https://github.com/happyfish100/fastdfs'
	select_version
	install_dir_set
	online_version
}

fastdfs_down(){

	online_down_file "${url}/archive/refs/tags/V${detail_version_number}.tar.gz"
	online_down_file "https://github.com/happyfish100/libfastcommon/archive/refs/tags/V1.0.53.tar.gz"
	unpacking_file ${tmp_dir}/V${detail_version_number}.tar.gz
	unpacking_file ${tmp_dir}/V1.0.53.tar.gz

}
fastdfs_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/fsatdfs/fastdfs-single.conf
		. ${workdir}/config/fsatdfs/fastdfs-single.conf
	else
		vi ${workdir}/config/fsatdfs/fastdfs-cluster.conf
		. ${workdir}/config/fsatdfs/fastdfs-cluster.conf
	fi
}

fastdfs_install(){

	info_log "正在安装相关依赖..."
	yum install gcc make -y
	cd ${tmp_dir}/libfastcommon-1.0.53
	home_dir=${install_dir}/fastdfs
	mkdir -p ${home_dir}
	#libfastcommon安装目录配置
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}/" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	./make.sh  && ./make.sh install
	if [[ $? = '0' ]];then
		success_log "libfastcommon安装完成"
	else
		error_log "libfastcommon安装失败"
		exit 1
	fi
	ln -sfn ${home_dir}/include/fastcommon /usr/include
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib/libfastcommon.so
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib64/libfastcommon.so
	#fastdfs安装目录配置
	cd ${tmp_dir}/fastdfs-${detail_version_number}
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
	sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh

	info_log "正在安装fastdfs服务..."
	./make.sh && ./make.sh install
	if [[ $? = '0' ]];then
		success_log "fastdfs安装完成"
	else
		error_log "fastdfs安装失败"
		exit 1
	fi
	ln -sfn ${home_dir}/include/fastdfs /usr/include
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib/libfdfsclient.so
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib64/libfdfsclient.so
	
	if [[ ${fastdht_enable} = "yes" ]];then
		yum install libdb-devel -y
		down_file https://github.com/hebaodanroot/fastdht/archive/patch-1.tar.gz ${tmp_dir}/fastdht-patch-1.tar.gz
		cd ${tmp_dir}
		tar -zxf fastdht-patch-1.tar.gz
		cd ${tmp_dir}/fastdht-patch-1
		#fastdht安装目录配置
		sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
		sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
		sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
		sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh
		./make.sh && ./make.sh install
		if [[ $? = '0' ]];then
			success_log "fastdht安装完成."
		else
			error_log "fastdht安装失败."
			exit 1
		fi
	fi
}

fastdfs_config(){
	mkdir -p ${data_dir}
	cp ${home_dir}/etc/tracker.conf.sample ${home_dir}/etc/tracker.conf
	cp ${home_dir}/etc/storage.conf.sample ${home_dir}/etc/storage.conf
	cp ${home_dir}/etc/client.conf.sample ${home_dir}/etc/client.conf
	cp ${tar_dir}/conf/http.conf ${home_dir}/etc
	cp ${tar_dir}/conf/mime.types ${home_dir}/etc
	cp ${workdir}/config/fastdfs/fastdfs_start.sh ${home_dir}/bin/start.sh && chmod +x ${home_dir}/bin/start.sh
	get_ip

	sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/client.conf
	sed -i "s#^tracker_server.*#tracker_server=${tracker_ip}#" ${home_dir}/etc/client.conf


	sed -i "s#^port.*#port=${tracker_port}#" ${home_dir}/etc/tracker.conf
	sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/tracker.conf
	
	sed -i "s#^port.*#port=${storage_port}#" ${home_dir}/etc/storage.conf
	sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#^store_path0.*#store_path0=${data_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#^tracker_server.*#\#tracker_server=${tracker_ip}#" ${home_dir}/etc/storage.conf
	#配置多个tracker_ip
	len=${#fastdht_ip[@]}
	for ((i=0;i<$len;i++))
	do
		sed -i "/#standard log/itracker_server=${tracker_ip[$i]}" ${home_dir}/etc/storage.conf
	done
	

	if [[ ${fastdht_enable} = 'yes' ]];then
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

	if [[ ${fastdht_enable} = 'yes' ]];then
		cp ${tmp_dir}/fastdht-patch-1/conf/fdhtd.conf ${home_dir}/etc/fdhtd.conf
		sed -i "s#^port.*#port=${fastdht_port}#" ${home_dir}/etc/fdhtd.conf
		sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/fdhtd.conf
	fi
	add_log_cut fastdfs ${data_dir}/logs/*.log
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_fastdfs_service(){
	
	Type="forking"
	ExecStart="${home_dir}/bin/fdfs_trackerd ${home_dir}/etc/tracker.conf start"
	PIDFile="${data_dir}/fdfs_trackerd.pid"
	add_daemon_file ${home_dir}/init
	add_system_service fdfs_trackerd ${home_dir}/init

	ExecStart="${home_dir}/bin/fdfs_storaged ${home_dir}/etc/storage.conf start"
	PIDFile="${data_dir}/fdfs_storaged.pid"
	add_daemon_file ${home_dir}/init
	add_system_service fdfs_storaged ${home_dir}/init

	if [[ ${install_fastdht} = 'y' ]];then
		ExecStart="${home_dir}/bin/fdhtd ${home_dir}/etc/fdhtd.conf start"
		PIDFile="${data_dir}/fdhtd.pid.pid"
		add_daemon_file ${home_dir}/init
		add_system_service fdhtd ${home_dir}/init
	fi
}

fastdfs_install_ctl(){
	fastdfs_env_load
	install_dir_set
	fastdfs_install_set
	fastdfs_down
	fastdfs_install
	fastdfs_config
	add_fastdfs_service
	
}
