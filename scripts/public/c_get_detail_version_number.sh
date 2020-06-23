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
				curl -Ls -o ${tmp_dir}/tmp_version ${galera_url} >/dev/null 2>&1

			fi

		;;
		mongodb)
			curl -sL -o ${tmp_dir}/tmp_version ${url}/x86_64-${version_number} >/dev/null 2>&1

		;;

	esac
	}

all_version_github(){

	case "$soft_name" in
		fastdfs)
			curl -sL -o ${tmp_dir}/all_version ${url}/tags >/dev/null 2>&1
		;;
	esac
	
}

ver_rule_general(){
	
	case "$soft_name" in
		java)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}u[0-9]{1,3}-b[0-9]{2}" | sort -u >${tmp_dir}/all_version
		;;
		
		php|ruby)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
		
		*|node)
			cat ${tmp_dir}/tmp_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u >${tmp_dir}/all_version
		;;
	esac

	option=$(cat ${tmp_dir}/all_version)
}


online_version(){
	[[ ! -d ${tmp_dir} ]] && mkdir -p ${tmp_dir}
	diy_echo "正在获取在线版本..." "" "${info}"
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
		fastdfs)
			all_version_github
		;;
	esac

	ver_rule_general
	
	output_option '请选择在线版本号' "${option}" 'detail_version_number'

	detail_version_number=(${output_value[@]})
	diy_echo "按任意键继续" "${yellow}" "${info}"
	read
}
