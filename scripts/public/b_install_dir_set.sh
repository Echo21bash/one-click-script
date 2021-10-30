#!/bin/bash

install_dir_set(){

	input_option "请输入安装路径" "/usr/local" "install_dir"
	install_dir=${input_value}
	pdir=$(dirname ${install_dir}) && bdir=$(basename ${install_dir})

	if [[ ${pdir} = '/' ]];then
		install_dir="${pdir}${bdir}"
	else
		install_dir="${pdir}/${bdir}"
	fi
	[[ ! -d ${install_dir} ]] && mkdir -p ${install_dir}
}
