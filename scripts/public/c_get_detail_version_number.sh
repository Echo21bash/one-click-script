#!/bin/bash


all_version_general1(){
	curl -Ls -o ${tmp_dir}/tmp_version ${url} >/dev/null 2>&1

}

all_version_general2(){
	curl -Ls -o ${tmp_dir}/tmp_version ${url}/${version_number}/ >/dev/null 2>&1
}
	
all_version_general3(){
	curl -sL -o ${tmp_dir}/tmp_version ${url}/${soft_name}-${version_number} >/dev/null 2>&1

}


all_version_other(){
	
	case "$soft_name" in

		mysql)
			if [[ ${branch} = '1' ]];then
				curl -Ls -o ${tmp_dir}/tmp_version ${url}/MySQL-${version_number} >/dev/null 2>&1

			else
				curl -Ls -o ${tmp_dir}/tmp_version ${url} >/dev/null 2>&1

			fi

		;;
		mongodb)
			curl -sL -o ${tmp_dir}/tmp_version ${url}/x86_64-${version_number} >/dev/null 2>&1

		;;

	esac
}

all_version_github(){

	case "$soft_name" in
		*)
			curl -sL ${url}/tags | grep /tag/ >/tmp/wireguard_tmp/tmp_version
		;;
	esac
	
}

ver_rule_general(){
	
	case "$soft_name" in
		java)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}u[0-9]{1,3}-b[0-9]{2}" | sort -u >${tmp_dir}/all_version
		;;
		
		php|ruby|nginx|mongodb|redis|zookeeper|kafka|zabbix|logstash|kibana|filebeat)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
		mysql)
			if [[ ${branch} = '1' ]];then
				cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
			else
				cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}-[0-9.]{5,}" | sort -u >${tmp_dir}/all_version
			fi
		;;		
		greenplum)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
		wireguard-ui)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1}\.[0-9]{1}" | sort -u >${tmp_dir}/all_version
		;;
		*|node|openresty|elasticsearch)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
	esac

	option=$(cat ${tmp_dir}/all_version)
}


online_version(){
	[[ ! -d ${tmp_dir} ]] && mkdir -p ${tmp_dir}
	diy_echo "正在获取在线版本..." "${info}"
	#所有可用版本
	case "$soft_name" in
		java|nginx|node|redis|memcached|php|zookeeper|kafka|activemq|rocketmq|zabbix|elasticsearch|logstash|kibana|filebeat|grafana)
			all_version_general1
		;;
		ruby)
			all_version_general2
		;;

		mysql|mongodb|tomcat|k8s)
			all_version_other
		;;
		fastdfs|greenplum|wireguard-ui)
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
