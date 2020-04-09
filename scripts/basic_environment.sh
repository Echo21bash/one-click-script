#!/bin/bash

check_java(){
	#检查旧版本
	echo -e "${info} 正在检查预装openjava..."
	j=`rpm -qa | grep  java | awk 'END{print NR}'`
	#卸载旧版
	if [ $j -gt 0 ];then
		echo -e "${info} java卸载清单:"
		for ((i=1;i<=j;i++));
		do		
			a1=`rpm -qa | grep java | awk '{if(NR == 1 ) print $0}'`
			echo $a1
			rpm -e --nodeps $a1
		done
		if [ $? = 0 ];then
			echo -e "${info} 卸载openjava完成."
		else
			echo -e "${error} 卸载openjava失败，请尝试手动卸载."
			exit 1
		fi
	else
		echo -e "${info} 该系统没有预装openjava."
	fi
}

install_java(){
	check_java
	mv ${tar_dir}/* ${home_dir}
	add_sys_env "JAVA_HOME=${home_dir} JAVA_BIN=\$JAVA_HOME/bin JAVA_LIB=\$JAVA_HOME/lib CLASSPATH=.:\$JAVA_LIB/tools.jar:\$JAVA_LIB/dt.jar PATH=\$JAVA_HOME/bin:\$PATH"
	java -version
	if [ $? = 0 ];then
		echo -e "${info} JDK环境搭建成功."
	else
		echo -e "${error} JDK环境搭建失败."
		exit 1
	fi
}

java_install_ctl(){
	install_version java
	install_selcet
	install_dir_set
	download_unzip
	install_java
	clear_install
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
	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	system_optimize_yum
	[[ ${os_release} < "7" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install  httpd httpd-devel mod_proxy_fcgi
	[[ ${os_release} > "6" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install httpd httpd-devel
	yum  -y install gcc gcc-c++ libxml2 libxml2-devel bzip2 bzip2-devel libmcrypt libmcrypt-devel openssl openssl-devel libcurl-devel libjpeg-devel libpng-devel freetype-devel readline readline-devel libxslt-devel perl perl-devel psmisc.x86_64 recode recode-devel libtidy libtidy-devel

}

php_install(){

	cd ${tar_dir}
	conf_dir=${home_dir}/etc
	extra_conf_dir=${home_dir}/etc.d
	mkdir -p ${home_dir}/{etc,etc.d}
	#必要函数库
	wget https://mirrors.huaweicloud.com/gnu/libiconv/libiconv-1.15.tar.gz && tar zxf libiconv-1.15.tar.gz && cd libiconv-1.15 && ./configure --prefix=/usr && make && make install && cd ..
	if [ $? = "0" ];then
		diy_echo "libiconv库编译及编译安装成功..." "" "${info}"
	else
		diy_echo "libiconv库编译及编译安装失败..." "${red}" "${error}"
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
		diy_echo "php编译完成..." "" "${info}"
	else
		diy_echo "php编译失败..." "${red}" "${error}"
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
			diy_echo "redis模块编译失败" "${red}" "${error}"
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
			diy_echo "memcached模块编译失败" "${red}" "${error}"
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
	install_version php
	install_selcet
	php_install_set
	install_dir_set
	download_unzip
	php_install_depend
	php_install
	clear_install
}

ruby_install_set(){
	output_option "请选择安装方式" "编译安装 RVM安装" "install_method"
}

ruby_install(){
	if [[ ${install_method} = '1' ]];then
		install -y zlib-devel openssl-devel
		cd ${tar_dir}
		./configure --prefix=${home_dir}  --disable-install-rdoc
		make && make install
		add_sys_env "PATH=${home_dir}/bin:\$PATH"

	else
		gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
		curl -L get.rvm.io | bash -s stable
		source /etc/profile.d/rvm.sh
		rvm install ${version_number}
		rvm use ${version_number} --default
	fi
	gem sources --add http://gems.ruby-china.com/ --remove http://rubygems.org/
	ruby -v
	if [ $? = 0 ];then
		echo -e "${info} ruby环境搭建成功."
	else
		echo -e "${error} ruby环境搭建失败."
		exit 1
	fi
}

ruby_install_ctl(){
	install_version ruby
	ruby_install_set
	if [[ ${install_method} = '1' ]];then
		install_selcet
		install_dir_set
		download_unzip
	fi
	ruby_install
	clear_install
}

node_install(){

	mv ${tar_dir}/* ${home_dir}
	add_sys_env "NODE_HOME=${home_dir} PATH=\${NODE_HOME}/bin:\$PATH"
	${home_dir}/bin/npm config set registry https://registry.npm.taobao.org
}

node_install_ctl(){
	install_version node
	install_selcet
	install_dir_set
	download_unzip
	node_install
	clear_install
}