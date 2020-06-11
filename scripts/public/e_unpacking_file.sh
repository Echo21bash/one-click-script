#!/bin/bash
unpacking_file(){
	file_name=${down_url##*/}
	#获取文件类型
	file_type=$(file -b ${tmp_dir}/${file_name} | grep -ioEw "gzip|zip|executable|text|bin" | tr [A-Z] [a-z])
	#获取文件目录
	if [[	${file_type} = 'gzip' ]];then
		dir_name=$(tar -tf ${tmp_dir}/${file_name}  | awk 'NR==1' | awk -F '/' '{print $1}' | sed 's#/##')
	elif [[ ${file_type} = 'zip' ]];then
		dir_name=$(unzip -v ${tmp_dir}/${file_name} | awk '{print $8}'| awk 'NR==4' | sed 's#/##')
	elif [[ ${file_type} = 'executable' ]];then
		dir_name=${soft_name}
	elif [[ ${file_type} = 'bin' ]];then
		dir_name=${soft_name}
	fi
	#解压文件
	diy_echo "Unpacking the file,please wait..." "" "${info}"
	if [[	${file_type} = 'gzip' ]];then
		tar -zxf ${tmp_dir}/${file_name} -C ${tmp_dir}
	elif [[ ${file_type} = 'zip' ]];then
		unzip -q ${tmp_dir}/${file_name} -d ${tmp_dir}
	fi
	
	if [[ $? = '0' ]];then
		diy_echo "Unpacking the file success." "" "${info}"
		tar_dir=${tmp_dir}/${dir_name}
	else
		diy_echo "Unpacking the file failed!" "" "${error}"
		exit 1
	fi
}