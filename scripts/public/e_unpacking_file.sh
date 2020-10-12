#!/bin/bash
unpacking_file(){
	##$1 待解压文件路径 $2解压至目录
	if [[ -z ${unpack_file_name} && -n $1 ]];then
		unpack_file_name=$1
	fi
	if [[ -z ${unpack_file_name} && -z $1 ]];then
		error_log "缺少变量unpack_file_name，或者参数\$1待解压文件路径"
	fi
	if [[ -z ${unpack_dir} && -n $2 ]];then
		unpack_dir=$1
	fi
	if [[ -z ${unpack_dir} && -z $2 ]];then
		error_log "缺少变量unpack_dir，或者参数\$2解压至目录"
	fi
	#获取文件类型
	file_type=$(file -b ${unpack_file_name} | grep -ioEw "gzip|zip|executable|text|bin" | tr [A-Z] [a-z])
	#获取文件目录
	info_log "正在获取压缩包根目录"
	if [[	${file_type} = 'gzip' ]];then
		package_root_dir=$(tar -tf ${tmp_dir}/${file_name}  | awk 'NR==1' | awk -F '/' '{print $1}' | sed 's#/##')
	elif [[ ${file_type} = 'zip' ]];then
		package_root_dir=$(unzip -v ${tmp_dir}/${file_name} | awk '{print $8}'| awk 'NR==4' | sed 's#/##')
	elif [[ ${file_type} = 'executable' ]];then
		package_root_dir=
	elif [[ ${file_type} = 'bin' ]];then
		package_root_dir=
	fi
	#解压文件
	info_log "正在解压文件${unpack_file_name}..."
	if [[	${file_type} = 'gzip' ]];then
		tar -zxf ${unpack_file_name} -C ${unpack_dir}
	elif [[ ${file_type} = 'zip' ]];then
		unzip -q ${unpack_file_name} -d ${unpack_dir}
	fi
	
	if [[ $? = '0' ]];then
		info_log "解压完成"
		tar_dir=${tmp_dir}/${dir_name}
	else
		error_log "解压失败"
		exit 1
	fi
}