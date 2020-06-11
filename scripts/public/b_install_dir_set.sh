#!/bin/bash
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
		if [[ `ls -A ${home_dir}` != '' ]];then
			diy_echo "Already existing folders${home_dir},Please check!" "" "${error}"
			exit 1
		fi
	fi
}
