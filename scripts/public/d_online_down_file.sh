#!/bin/bash

online_down_file(){

	if [[ -n $1 ]];then
		down_url=$1
	fi
	if [[ -z ${down_url} ]];then
		error_log "函数online_down_file缺少变量down_url，或者参数\$1下载文件地址"
		exit 1
	fi

	if [[ -z ${down_file_rename} ]];then
		down_file_name=${down_url##*/}
	else
		down_file_name=${down_file_rename}

	fi
	
	if [[ -z ${tmp_dir} ]];then
		tmp_dir=/tmp
	fi
	down_url=`eval echo ${down_url}`
	
	if [[ ! -d ${tmp_dir} ]];then
		mkdir -p ${tmp_dir}
	fi

	down_file ${down_url} ${tmp_dir}/${down_file_name}

}