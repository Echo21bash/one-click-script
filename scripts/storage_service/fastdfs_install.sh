#!/bin/bash

fastdfs_env_load(){

	soft_name=fastdfs
	tmp_dir=/tmp/fastdfs_tmp
	url='https://github.com/happyfish100/fastdfs'
	down_url="${url}/archive/master.tar.gz"

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
	yum install gcc make -y
	cd ${tar_dir}
	diy_echo "正在安装相关依赖..." "" "${info}"
	down_file https://github.com/happyfish100/libfastcommon/archive/master.tar.gz ${tmp_dir}/libfastcommon-master.tar.gz
	cd ${tmp_dir}
	tar -zxf libfastcommon-master.tar.gz
	cd ${tmp_dir}/libfastcommon-master
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
	fastdfs_env_load
	install_dir_set
	fastdfs_install_set
	online_down_file
	unpacking_file
	fastdfs_install
	fastdfs_config
	add_fastdfs_service
	clear_install
}
