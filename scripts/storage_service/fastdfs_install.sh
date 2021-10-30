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
	unpacking_file ${tmp_dir}/V${detail_version_number}.tar.gz ${tmp_dir}
	unpacking_file ${tmp_dir}/V1.0.53.tar.gz ${tmp_dir}

}
fastdfs_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		vi ${workdir}/config/fastdfs/fastdfs-single.conf 
		. ${workdir}/config/fastdfs/fastdfs-single.conf
	else
		vi ${workdir}/config/fastdfs/fastdfs-cluster.conf
		. ${workdir}/config/fastdfs/fastdfs-cluster.conf
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
		success_log "libfastcommon编译完成"
	else
		error_log "libfastcommon编译失败"
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

	info_log "正在编译fastdfs服务..."
	./make.sh && ./make.sh install
	if [[ $? = '0' ]];then
		success_log "fastdfs编译完成"
	else
		error_log "fastdfs编译失败"
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
			success_log "fastdht编译完成."
		else
			error_log "fastdht编译失败."
			exit 1
		fi
	fi

	if [[ ${deploy_mode} = '1' ]];then
		fastdfs_config
		add_fastdfs_service
	fi
}

fastdfs_config(){

	if [[ ${deploy_mode} = '1' ]];then
		mkdir -p ${data_dir}
		cp ${home_dir}/etc/tracker.conf.sample ${home_dir}/etc/tracker.conf
		cp ${home_dir}/etc/storage.conf.sample ${home_dir}/etc/storage.conf
		cp ${home_dir}/etc/client.conf.sample ${home_dir}/etc/client.conf
		cp ${tmp_dir}/fastdfs-${detail_version_number}/conf/http.conf ${home_dir}/etc
		cp ${tmp_dir}/fastdfs-${detail_version_number}/conf/mime.types ${home_dir}/etc
		get_ip
		sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/client.conf
		sed -i "s#^tracker_server.*#tracker_server=${local_ip}:22000#" ${home_dir}/etc/client.conf


		sed -i "s#^port.*#port=22000#" ${home_dir}/etc/tracker.conf
		sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/tracker.conf
		
		sed -i "s#^port.*#port=23000#" ${home_dir}/etc/storage.conf
		sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/storage.conf
		sed -i "s#^store_path0.*#store_path0=${data_dir}#" ${home_dir}/etc/storage.conf
		sed -i "s#^tracker_server.*#tracker_server=${local_ip}:22000#" ${home_dir}/etc/storage.conf
		if [[ ${fastdht_enable} = 'yes' ]];then
			sed -i "s#^check_file_duplicate.*#check_file_duplicate=1#" ${home_dir}/etc/storage.conf
			sed -i "s?##include /home/yuqing/.*?#include ${home_dir}/etc/fdht_servers.conf?" ${home_dir}/etc/storage.conf
		fi

		if [[ ${fastdht_enable} = 'yes' ]];then
			cp ${tmp_dir}/fastdht-patch-1/conf/fdhtd.conf ${home_dir}/etc/fdhtd.conf
			sed -i "s#^port.*#port=24000#" ${home_dir}/etc/fdhtd.conf
			sed -i "s#^base_path.*#base_path=${data_dir}#" ${home_dir}/etc/fdhtd.conf
			sed -i "s#^group_count =.*#group_count = 1#" ${home_dir}/etc/fdht_servers.conf
			echo "group0 = ${local_ip}:24000" >>${home_dir}/etc/fdht_servers.conf
		fi
		add_log_cut fastdfs ${data_dir}/logs/*.log
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
	fi

	if [[ ${deploy_mode} = '2' ]];then
		#配置多个tracker_ip
		len=${#fastdht_ip[@]}
		for ((i=0;i<$len;i++))
		do
			sed -i "/#standard log/itracker_server=${tracker_ip[$i]}" ${home_dir}/etc/storage.conf
		done
	fi


}

add_fastdfs_service(){
	
	Type="forking"
	ExecStart="${home_dir}/bin/fdfs_trackerd ${home_dir}/etc/tracker.conf start"
	PIDFile="${data_dir}/data/fdfs_trackerd.pid"
	add_daemon_file ${home_dir}/init
	add_system_service fdfs-trackerd ${home_dir}/init

	ExecStart="${home_dir}/bin/fdfs_storaged ${home_dir}/etc/storage.conf start"
	PIDFile="${data_dir}/data/fdfs_storaged.pid"
	add_daemon_file ${home_dir}/init
	add_system_service fdfs-storaged ${home_dir}/init

	if [[ ${fastdht_enable} = 'yes' ]];then
		ExecStart="${home_dir}/bin/fdhtd ${home_dir}/etc/fdhtd.conf start"
		PIDFile="${data_dir}/data/fdhtd.pid"
		add_daemon_file ${home_dir}/init
		add_system_service fdhtd ${home_dir}/init
	fi
}

fastdfs_install_ctl(){
	fastdfs_env_load
	fastdfs_install_set
	fastdfs_down
	fastdfs_install
}
