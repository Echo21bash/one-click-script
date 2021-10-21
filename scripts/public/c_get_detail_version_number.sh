#!/bin/bash

all_version_general1(){
	timeout 3 curl --connect-timeout 3 -Ls -o ${tmp_dir}/tmp_version ${url} >/dev/null 2>&1

}

all_version_general2(){
	timeout 3 curl --connect-timeout 3 -Ls -o ${tmp_dir}/tmp_version ${url}/${version_number}/ >/dev/null 2>&1
}
	
all_version_general3(){
	timeout 3 curl --connect-timeout 3 -sL -o ${tmp_dir}/tmp_version ${url}/${soft_name}-${version_number} >/dev/null 2>&1

}


all_version_other(){
	
	case "$soft_name" in

		mysql)
			if [[ ${branch} = '1' ]];then
				timeout 3 curl --connect-timeout 3 -Ls -o ${tmp_dir}/tmp_version ${url}/MySQL-${version_number} >/dev/null 2>&1

			else
				timeout 3 curl --connect-timeout 3 -Ls -o ${tmp_dir}/tmp_version ${url} >/dev/null 2>&1

			fi

		;;
		mongodb)
			timeout 3 curl --connect-timeout 3 -sL -o ${tmp_dir}/tmp_version ${url}/x86_64-${version_number} >/dev/null 2>&1

		;;

	esac
}

all_version_github(){

	case "$soft_name" in
		*)
			timeout 3 curl --connect-timeout 3 -sL ${url}/tags | grep /tag/ >${tmp_dir}/tmp_version
		;;
	esac
	
}

ver_rule_general(){

	ver=`echo ${version_number} | sed 's/\./\\\\./'`
	case "$soft_name" in
		java)
			if [[ ${version_number} -lt '9' ]];then
				cat ${tmp_dir}/tmp_version | grep -Eio "${ver}u[0-9]{1,3}-b[0-9]{2}" | sort -u >${tmp_dir}/all_version
			else
				cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,3}\.[0-9]{1,3}\+[0-9]{1,3}" | sort -u >${tmp_dir}/all_version
			fi
		;;
		
		erlang|go|php|ruby|nginx|memcached|mongodb|redis|zookeeper|kafka|rabbitmq|zabbix)
			cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
		mysql)
			if [[ ${branch} = '1' ]];then
				cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
			else
				cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,2}-[0-9.]{5,}" | sort -u >${tmp_dir}/all_version
			fi
		;;		
		greenplum)
			cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
		wireguard-ui|anylink)
			cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1}\.[0-9]{1}" | sort -u >${tmp_dir}/all_version
		;;
		*|node|openresty|elasticsearch|logstash|kibana|filebeat)
			cat ${tmp_dir}/tmp_version | grep -Eio "${ver}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
	esac

	option=$(cat ${tmp_dir}/all_version)
}


online_version(){
	[[ ! -d ${tmp_dir} ]] && mkdir -p ${tmp_dir}
	diy_echo "正在获取在线版本..." "${info}"
	#所有可用版本
	case "$soft_name" in
		erlang|java|go|nginx|openresty|node|redis|memcached|php|zookeeper|kafka|activemq|rocketmq|rabbitmq|zabbix|elasticsearch|logstash|kibana|filebeat|grafana)
			all_version_general1
		;;
		ruby)
			all_version_general2
		;;
		tomcat)
			all_version_general3
		;;
		mysql|mongodb|tomcat|k8s)
			all_version_other
		;;
		fastdfs|greenplum|wireguard-ui|anylink)
			all_version_github
		;;
	esac

	ver_rule_general
	
	output_option '请选择在线版本号' "${option} 自定义版本" 'detail_version_number'

	detail_version_number=(${output_value[@]})
	
	if [[ ${detail_version_number} = '自定义版本' ]];then
		input_option '请输入版本号' '0.0.0' 'detail_version_number'
		detail_version_number=${input_value}
	fi
	diy_echo "按任意键继续" "${yellow}" "${info}"
	read
}
