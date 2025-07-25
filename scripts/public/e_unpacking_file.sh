#!/bin/bash

unpacking_file(){
	##$1 待解压文件路径 $2解压至目录
	if [[ -n $1 ]];then
		unpack_file_name=$1
	fi
	if [[ -z ${unpack_file_name} ]];then
		error_log "函数unpacking_file缺少变量unpack_file_name，或者参数\$1待解压文件路径"
	fi
	if [[ -n $2 ]];then
		unpack_dir=$2
	fi
	if [[ -z ${unpack_dir} ]];then
		error_log "缺少变量unpack_dir，或者参数\$2解压至目录"
	fi
	#获取文件类型
	if [[ ! -f ${unpack_file_name} ]];then
		error_log "不存在文件${unpack_file_name}"
		exit 1
	fi
	file_type=$(file -b ${unpack_file_name} | grep -ioEw "gzip|XZ|zip|executable|text|bin" | tr [A-Z] [a-z])
	#获取文件目录
	info_log "正在获取压缩包根目录"
	if [[ ${file_type} = 'gzip' || ${file_type} = 'xz' ]];then
		package_root_dir=$(tar -tf ${unpack_file_name}| grep -o '^[^/]\+/' | sed 's|/$||' | sort -u)
	elif [[ ${file_type} = 'zip' ]];then
		package_root_dir=$(unzip -l ${unpack_file_name} | awk '/\/$/ && !/^[ \t]*$/ {split($4, arr, "/"); if (arr[2] == "") print arr[1]}' | sort -u)
	elif [[ ${file_type} = 'executable' ]];then
		package_root_dir=
	elif [[ ${file_type} = 'bin' ]];then
		package_root_dir=
	fi
	#解压文件
	if [[ -d ${unpack_dir}/${package_root_dir} ]];then
		rm -rf ${unpack_dir}/${package_root_dir}
	fi
	info_log "正在解压文件${unpack_file_name}到${unpack_dir}"
	if [[ ! -d ${unpack_dir} ]];then
		mkdir -p ${unpack_dir}
	fi
	
	if [[ ${file_type} = 'gzip' || ${file_type} = 'xz' ]];then
		tar -xf ${unpack_file_name} -C ${unpack_dir}
	elif [[ ${file_type} = 'zip' ]];then
		unzip -q ${unpack_file_name} -d ${unpack_dir}
	fi
	
	if [[ $? = '0' ]];then
		info_log "解压完成"
		tar_dir=${unpack_dir}/${package_root_dir}
	else
		error_log "解压失败"
		exit 1
	fi
}