#!/bin/bash

php_env_load(){
	
	tmp_dir=/tmp/php_tmp
	soft_name=php
	program_version=('5.6' '7.0' '7.1')
	url="http://mirrors.sohu.com/php/"
	select_version
	install_dir_set
	online_version

}

php_down(){
	down_url="${url}/php-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/php-${detail_version_number}.tar.gz ${tmp_dir}
}

php_install_set(){
	output_option '请选择安装模式' 'PHP作为httpd模块 FastCGI(php-fpm)模式 PHP同时开启两个种模式' 'php_mode'
	input_option '是否添加额外模块' 'n' 'add'
	add=${input_value}
	yes_or_no ${add}
	if [[ $? = '0' ]];then
		output_option '请选择需要安装的php模块(可多选)' 'redis memcached' 'php_modules'
		php_modules=(${output_value[@]})
	fi

}

php_install_depend(){
	#安装编译工具及库文件
	info_log "正在安装编译工具及库文件..."
	system_optimize_yum
	[[ ${os_release} < "7" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install  httpd httpd-devel mod_proxy_fcgi
	[[ ${os_release} > "6" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install httpd httpd-devel
	yum  -y install gcc gcc-c++ libxml2 libxml2-devel bzip2 bzip2-devel libmcrypt libmcrypt-devel openssl openssl-devel libcurl-devel libjpeg-devel libpng-devel freetype-devel readline readline-devel libxslt-devel perl perl-devel psmisc.x86_64 recode recode-devel libtidy libtidy-devel sqlite-devel

}

php_install(){

	home_dir=${install_dir}/php
	conf_dir=${home_dir}/etc
	extra_conf_dir=${home_dir}/etc.d
	mkdir -p ${home_dir}/{etc,etc.d}
	#必要函数库
	down_file https://mirrors.huaweicloud.com/gnu/libiconv/libiconv-1.15.tar.gz ${tmp_dir}/libiconv-1.15.tar.gz
	cd ${tmp_dir} && tar zxf libiconv-1.15.tar.gz && cd libiconv-1.15 && ./configure --prefix=/usr && make && make install
	cd ${tar_dir}	
	
	if [ $? = "0" ];then
		info_log "libiconv库编译及编译安装成功..."
	else
		error_log "libiconv库编译及编译安装失败..."
		exit 1
	fi
	php_compile
	php_config
	if [[ ${php_modules[@]} != '' ]];then
		php_modules_install
	fi
}

php_compile(){
	#编译参数获取
	[ ${php_mode} = 1 ] && fpm="" && apxs2="--with-apxs2=`find / -name apxs`"
	[ ${php_mode} = 2 ] && fpm="--enable-fpm" && apxs2=""
	[ ${php_mode} = 3 ] && fpm="--enable-fpm" && apxs2="--with-apxs2=`which apxs`"
	[[ ${version_number} < '7.0' ]] && mysql="--with-mysql=mysqlnd"
	[[ ${version_number} = '7.0' || ${version_number} > '7.0' ]] && mysql=""
	./configure --prefix=${home_dir} --with-config-file-path=${home_dir}/etc --with-config-file-scan-dir=${home_dir}/etc.d ${fpm} ${apxs2} ${mysql} --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-mhash --with-openssl --with-zlib --with-bz2 --with-curl --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-zlib --enable-mbstring --with-mcrypt --enable-sockets --with-iconv-dir --with-xsl --enable-zip --with-pcre-dir --with-pear --enable-session  --enable-gd-native-ttf --enable-xml --with-freetype-dir --enable-inline-optimization --enable-shared --enable-bcmath --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-mbregex --enable-pcntl --with-xmlrpc --with-gettext --enable-exif --with-readline --with-recode --with-tidy --enable-soap
	make && make install
	if [ $? = "0" ];then
		info_log "php编译完成..."
	else
		error_log "php编译失败..."
		exit 1
	fi

}

php_modules_install(){
	php_redis='https://github.com/phpredis/phpredis'
	php_memcached='https://github.com/php-memcached-dev/php-memcached'
	
	if [[ ${php_modules[@]} =~ 'redis' ]];then

		[[ ${version_number} > '5.6' ]] && wget ${php_redis}/archive/master.tar.gz -O  phpredis-master.tar.gz && tar zxf phpredis-master.tar.gz && cd phpredis-master
		[[ ${version_number} < '7.0' ]] && wget ${php_redis}/archive/4.3.0.tar.gz -O  phpredis-4.3.0.tar.gz && tar zxf phpredis-4.3.0.tar.gz && cd phpredis-4.3.0
		${home_dir}/bin/phpize
		./configure --with-php-config=${home_dir}/bin/php-config && make && make install && cd ..
		if [[ $? = '0' ]];then
			cat > ${extra_conf_dir}/redis.ini<<-EOF
			[redis]
			extension = redis.so
			EOF
		else
			error_log "redis模块编译失败"
			exit
		fi
	fi

	if [[ ${php_modules[@]} =~ 'memcached' ]];then
		#安装依赖的库和头文件
		yum install -y libmemcached libmemcached-devel
		[[ ${version_number} > '5.6' ]] && wget ${php_memcached}/archive/master.tar.gz -O  php-memcached-master.tar.gz && tar zxf php-memcached-master.tar.gz && cd php-memcached-master
		[[ ${version_number} < '7.0' ]] && wget ${php_memcached}/archive/2.2.0.tar.gz -O  php-memcached-2.2.0.tar.gz && tar zxf php-memcached-2.2.0.tar.gz && cd php-memcached-2.2.0
		${home_dir}/bin/phpize
		./configure --with-php-config=${home_dir}/bin/php-config && make && make install && cd ..
		if [[ $? = '0' ]];then
			cat > ${extra_conf_dir}/memcached.ini<<-EOF
			[memcached]
			extension = memcached.so
			EOF
		else
			error_log "memcached模块编译失败"
			exit
		fi
	fi
}

php_config(){

	cp ./php.ini-production ${conf_dir}/php.ini
	#最大上传相关配置
	sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${conf_dir}/php.ini
	sed -i 's/post_max_size =.*/post_max_size = 60M/g' ${conf_dir}/php.ini
	sed -i 's/memory_limit =.*/memory_limit = 128M/g' ${conf_dir}/php.ini
	sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${conf_dir}/php.ini
	sed -i 's/max_input_time =.*/max_input_time = 300/g' ${conf_dir}/php.ini
	#其它
	sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${conf_dir}/php.ini
  
	if [[ ${php_mode} = 2 || ${php_mode} = 3 ]];then
		if [[ ${version_number} > '5.6' ]];then
			cp ${conf_dir}/php-fpm.d/www.conf.default ${conf_dir}/php-fpm.d/www.conf
			cp ${conf_dir}/php-fpm.conf.default ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_children =.*/pm.max_children = 10/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.start_servers =.*/pm.start_servers = 4/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 2/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 6/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/;pm.max_requests =.*/pm.max_requests = 1024/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's#;pm.status_path =.*#;pm.status_path = /php_status#' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's#;ping.path =.*#ping.path = /ping#' ${conf_dir}/php-fpm.d/www.conf
		else
			cp ${conf_dir}/php-fpm.conf.default ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_children =.*/pm.max_children = 10/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.start_servers =.*/pm.start_servers = 4/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 2/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 6/' ${conf_dir}/php-fpm.conf
			sed -i 's/;pm.max_requests =.*/pm.max_requests = 1024/' ${conf_dir}/php-fpm.conf
			sed -i 's#;pm.status_path =.*#;pm.status_path = /php_status#' ${conf_dir}/php-fpm.conf
			sed -i 's#;ping.path =.*#ping.path = /ping#' ${conf_dir}/php-fpm.conf
		fi
		if [[ ${os_release} < '7' ]];then
			cp ./sapi/fpm/init.d.php-fpm ${home_dir}/php_fpm_init
		else
			sed -i 's#${prefix}#'${home_dir}'#' ./sapi/fpm/php-fpm.service
			sed -i 's#${exec_prefix}#'${home_dir}'#' ./sapi/fpm/php-fpm.service
			cp ./sapi/fpm/php-fpm.service ${home_dir}/php_fpm_init
		fi
	fi
	add_system_service php-fpm ${home_dir}/php_fpm_init
	add_sys_env "PATH=${home_dir}/bin:\$PATH PATH=${home_dir}/sbin:\$PATH"
}

php_install_ctl(){
	php_env_load
	php_install_set
	php_down
	php_install_depend
	php_install
	clear_install
}
