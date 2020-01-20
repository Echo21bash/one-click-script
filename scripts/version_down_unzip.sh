#!/bin/bash
install_version(){
	#需要传参$1软件名称
	soft_name="$1"
	version='_version'
	java_version=('7' '8')
	node_version=('9' '10')
	ruby_version=('2.3' '2.4')
	tomcat_version=('7' '8')
	mysql_version=('5.5' '5.6' '5.7')
	mongodb_version=('3.4' '3.6' '4.0')
	nginx_version=('1.14' '1.15' '1.16')
	php_version=('5.6' '7.0' '7.1')
	redis_version=('3.2' '4.0' '5.0')
	memcached_version=('1.4' '1.5')
	zookeeper_version=('3.4')
	kafka_version=('2.2')
	activemq_version=('5.13' '5.14' '5.15')
	rocketmq_version=('4.2' '4.3')
	hadoop_version=('2.9' '3.0' '3.1')
	zabbix_version=('3.4' '4.0')
	elasticsearch_version=('5.6' '6.1' '6.2')
	logstash_version=('5.6' '6.1' '6.2')
	kibana_version=('5.6' '6.1' '6.2')
	filebeat_version=('5.6' '6.1' '6.2')
	k8s_version=('1.11' '1.12' '1.13' '1.14')
	program_version=`eval echo '$'{$soft_name$version[@]}`
	output_option "请选择${soft_name}版本" "${program_version[@]}" "version_number"
	version_number=${output_value}
}

install_selcet(){
	output_option "请选择安装方式版本" "在线安装 本地安装" "install_mode"
}

local_install(){

	while true
	do
		[ ${os_bit} = 64 ] && echo -e "${info} 请输入${soft_name}64位安装包路径(如:/opt/xxx-x64.tar.gz)"
		[ ${os_bit} = 32 ] && echo -e "${info} 请输入${soft_name}32位安装包路径(如:/opt/xxx-i586.tar.gz)"

		stty erase '^H' && read user_inpt
		if [  -f "$user_inpt" ];then
			cd ${install_dir}
			echo -e "${info} Copying compressed package, please wait" && \cp  ${user_inpt}  ${install_dir}/${file_name} && break
		else
			echo -e "${error} File does not exist, please enter the correct path"
		fi
	done
}

online_url(){

	java_url='https://repo.huaweicloud.com/java/jdk'
	java_url="http://mirrors.linuxeye.com/jdk"
	ruby_url="http://mirrors.ustc.edu.cn/ruby"
	node_url="http://mirrors.ustc.edu.cn/node"
	#tomcat_url="http://archive.apache.org/dist/tomcat"
	tomcat_url="http://mirrors.ustc.edu.cn/apache/tomcat"

	#mysql_url=('http://mirrors.ustc.edu.cn/mysql-ftp/Downloads' 'http://mirrors.163.com/mysql/Downloads')
	mysql_url='http://mirrors.163.com/mysql/Downloads'
	mysql_galera_url='http://releases.galeracluster.com'
	mongodb_url="https://www.mongodb.org/dl/linux"
	nginx_url="http://nginx.org/download"
	php_url="http://mirror.cogentco.com/pub/php"
	php_url="http://mirrors.sohu.com/php/"
	
	redis_url="https://mirrors.huaweicloud.com/redis"
	memcached_url='https://github.com/memcached/memcached'
	memcached_url="https://mirrors.huaweicloud.com/memcached"
	zookeeper_url="http://mirrors.ustc.edu.cn/apache/zookeeper"
	kafka_url='http://mirrors.ustc.edu.cn/apache/kafka'
	activemq_url="https://mirrors.huaweicloud.com/apache/activemq"
	rocketmq_url="http://mirrors.ustc.edu.cn/apache/rocketmq"
	hadoop_url="http://mirrors.ustc.edu.cn/apache/hadoop/common"
	fastdfs_url='https://github.com/happyfish100/fastdfs'
	minio_url='https://dl.minio.io/server/minio/release/linux-amd64/minio'
	elasticsearch_url='https://mirrors.huaweicloud.com/elasticsearch'
	logstash_url='https://mirrors.huaweicloud.com/logstash'
	kibana_url='https://mirrors.huaweicloud.com/kibana'
	filebeat_url='https://mirrors.huaweicloud.com/filebeat'
	zabbix_url='https://sourceforge.mirrorservice.org/z/za/zabbix/ZABBIX%20Latest%20Stable'
	grafana_url='https://mirrors.huaweicloud.com/grafana'
	#url=($(eval echo '$'{${soft_name}_url[@]}))
	url=$(eval echo '$'{${soft_name}_url})
}

online_version(){

	all_version_general(){
		curl -Ls -o /tmp/all_version ${url} >/dev/null 2>&1
	}
	
	all_version_other(){
	case "$soft_name" in
		mysql)
			if [[ ${branch} = '1' ]];then
				curl -sL ${mysql_url}/MySQL-${version_number} >/tmp/all_version
			else
				curl -sL ${mysql_galera_url}/mysql-wsrep-${version_number}/binary >/tmp/all_version
			fi
		;;
		mongodb)
			curl -sL -o /tmp/all_version ${url}/x86_64-${version_number} >/dev/null 2>&1
		;;
		tomcat)
			curl -sL -o /tmp/all_version ${url}/${soft_name}-${version_number} >/dev/null 2>&1
		;;
		k8s)
			yum list --showduplicates kubeadm >/tmp/all_version
		;;
	esac
	}

	ver_rule_general(){
		option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}

	ver_rule_general1(){
		option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}

	ver_rule_general2(){
		option=$(cat /tmp/all_version | grep -Eio "${soft_name}-${version_number}.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}
	
	ver_rule_last_rev(){
		option='latest version'
	}
	
	ver_rule_other(){
	
		case "$soft_name" in
		java)
			if [[ ${os_bit} = '64' ]];then
				option=$(cat /tmp/all_version | grep -Eio "jdk-${version_number}u.*x64" | sort -u)
			else
				option=$(cat /tmp/all_version | grep -Eio "jdk-${version_number}u.*i586" | sort -u)
			fi
		;;
		node)
			option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u -n  -k 2 -t '.')
		;;
	esac

	}


	diy_echo "正在获取在线版本..." "" "${info}"
	#generated_version
	case "$soft_name" in
		node|nginx|redis|memcached|php|zookeeper|kafka|activemq|rocketmq|zabbix|elasticsearch|logstash|kibana|filebeat|grafana)
			all_version_general
		;;
		java)
			curl -sL -o /tmp/all_version ${url}/md5sum.txt >/dev/null 2>&1
		;;
		ruby)
			curl -sL -o /tmp/all_version ${url}/${version_number} >/dev/null 2>&1
		;;
		mysql|mongodb|tomcat|k8s)
			all_version_other
		;;

	esac

	#ver_rule
	case "$soft_name" in
		ruby|mysql|mongodb|zookeeper|kafka|activemq|rocketmq|elasticsearch|logstash|kibana|filebeat|zabbix|k8s|grafana)
			ver_rule_general
		;;
		tomcat)
			ver_rule_general1
		;;
		nginx|redis|memcached|php)
			ver_rule_general2
		;;
		fastdfs|minio)
			ver_rule_last_rev
		;;
		java|node)
			ver_rule_other
		;;
	esac

	output_option '请选择在线版本号' "${option}" 'online_select_version'
	[ -z ${online_select_version} ] && diy_echo "镜像站没有该版本" "$red" "$error" && exit 1
	online_select_version=(${output_value[@]})
	diy_echo "按任意键继续" "${yellow}" "${info}"
	read
}

online_down(){
	#拼接下载链接
	case "$soft_name" in
		java|nginx|redis|memcached|php)
			down_url="${url}/${online_select_version}.tar.gz"
		;;
		ruby)
			down_url="${url}/${soft_name}-${online_select_version}.tar.gz"
		;;
		elasticsearch|logstash)
			down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}.tar.gz"
		;;
		kibana|filebeat)
			if [[ ${os_bit} = '64' ]];then
				down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}-linux-x86_64.tar.gz"
			else
				down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}-linux-x86.tar.gz"
			fi
		;;
		node)
			down_url="${url}/v${online_select_version}/node-v${online_select_version}-linux-x64.tar.gz"
		;;
		mysql)
			if [[ ${branch} = '1' ]];then
				[[ ${os_bit} = '64' ]] && down_url="${url}/MySQL-${version_number}/mysql-${online_select_version}-linux-glibc2.12-x86_64.tar.gz"
				[[ ${os_bit} = '32' ]] && down_url="${url}/MySQL-${version_number}/mysql-${online_select_version}-linux-glibc2.12-i686.tar.gz"
			else
				[[ ${os_bit} = '64' ]] && down_url="${mysql_galera_url}/mysql-wsrep-${version_number}/binary/mysql-wsrep-${online_select_version}-`cat /tmp/all_version | grep -Eio "[0-9]{2}\.[0-9]{2}" | sort -u`-linux-x86_64.tar.gz"
			fi
		;;
		mongodb)
			down_url="http://downloads.mongodb.org/linux/mongodb-linux-x86_64-${online_select_version}.tgz"
		;;
		tomcat)
			down_url="${url}/tomcat-${version_number}/v${online_select_version}/bin/apache-tomcat-${online_select_version}.tar.gz"
		;;
		zookeeper)
			down_url="${url}/zookeeper-${online_select_version}/zookeeper-${online_select_version}.tar.gz"
		;;
		kafka)
			down_url="${url}/${online_select_version}/kafka_2.11-${online_select_version}.tgz"
		;;
		activemq)
			down_url="${url}/${online_select_version}/apache-activemq-${online_select_version}-bin.tar.gz"
		;;
		rocketmq)
			down_url="${url}/${online_select_version}/rocketmq-all-${online_select_version}-bin-release.zip"
		;;
		fastdfs)
			down_url="${url}/archive/master.tar.gz"
		;;
		minio)
			down_url="${url}"
		;;
		zabbix)
			down_url="${url}/${online_select_version}/zabbix-${online_select_version}.tar.gz"
		;;
		grafana)
			down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}.linux-amd64.tar.gz"
		;;
	esac

	cd ${install_dir} && axel -n 10 -a ${down_url} -o ${file_name}
  if [ $? = '0' ];then
		diy_echo "${online_select_version}下载完成..." "" "${info}"
	else
		diy_echo "${online_select_version}下载失败..." "${red}" "${error}"
		exit 1
	fi
}

install_dir_set(){
	#需要传参$1软件名称
	[[ -z ${soft_name} ]] && soft_name="$1"
	input_option "请输入安装路径" "/opt" "install_dir"
	install_dir=${input_value}
	pdir=$(dirname ${install_dir}) && bdir=$(basename ${install_dir})

	if [[ ${pdir} = '/' ]];then
		install_dir="${pdir}${bdir}"
	else
		install_dir="${pdir}/${bdir}"
	fi
	[[ ! -d ${install_dir} ]] && mkdir -p ${install_dir}
	#判断是否存在已有目录
	home_dir=${install_dir}/${soft_name}
	if [[ ! -d ${home_dir} ]];then
		mkdir -p ${home_dir}
	else
		diy_echo "Already existing folders${home_dir},Please check!" "" "${error}"
		exit 1
	fi
}

download_unzip(){

	if [[ ${soft_name} = 'rocketmq' ]];then
		file_name="${soft_name}.zip"
	elif [[ ${soft_name} = 'mongodb' ]];then
		file_name="${soft_name}.tgz"
	elif [[ ${soft_name} = 'minio' ]];then
		file_name="${soft_name}-release"
	else
		file_name="${soft_name}.tar.gz"
	fi
	
	if [ ${install_mode} = 1 ];then
		online_url
		online_version
		online_down
	elif [ ${install_mode} = 2 ];then
		local_install
	fi
	#获取文件类型
	file_type=$(file -b ${install_dir}/${file_name} | grep -ioEw "gzip|zip|executable|text" | tr [A-Z] [a-z])
	#获取文件目录
	if [[	${file_type} = 'gzip' ]];then
		dir_name=$(tar -tf ${install_dir}/${file_name}  | awk 'NR==1' | awk -F '/' '{print $1}' | sed 's#/##')
	elif [[ ${file_type} = 'zip' ]];then
		dir_name=$(unzip -v ${install_dir}/${file_name} | awk '{print $8}'| awk 'NR==4' | sed 's#/##')
	elif [[ ${file_type} = 'executable' ]];then
		dir_name=${soft_name}
	fi

	#解压文件
	diy_echo "Unpacking the file,please wait..." "" "${info}"
	if [[	${file_type} = 'gzip' ]];then
		tar -zxf ${install_dir}/${file_name} -C ${install_dir}
	elif [[ ${file_type} = 'zip' ]];then
		unzip -q ${install_dir}/${file_name} -d ${install_dir}
	fi
	
	if [[ $? = '0' ]];then
		diy_echo "Unpacking the file success." "" "${info}"
		tar_dir=${install_dir}/${dir_name}
	else
		diy_echo "Unpacking the file failed!" "" "${error}"
		exit 1
	fi

}
