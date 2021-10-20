#!/bin/bash
set -e

k8s_install_set(){

	output_option "选择安装方式" "kubeadm 二进制安装" install_method

}

k8s_install_ctl(){

	k8s_install_set
	if [[ ${install_method} = '1' ]];then
		k8s_yum_install
	else
		k8s_bin_install
	fi

}