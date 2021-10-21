#!/bin/bash

select_version(){
	if [[ -z ${program_version} ]];then
		diy_echo "函数select_version缺少program_version变量" "${error}"
		exit 1
	fi
	if [[ -z ${soft_name} ]];then
		diy_echo "函数select_version缺少soft_name变量" "${error}"
		exit 1
	fi
	output_option "请选择${soft_name}版本" "${program_version[*]}" "version_number"
	version_number=${output_value}
}