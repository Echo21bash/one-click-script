#!/bin/bash

update_kernel(){
	warning_log "请谨慎更新内核,需要重新系统！！"
	output_option '选择升级kernel类型' 'centos官方 elrepo版本' 'kernel_type'

    if [[ ${sys_name} = "Centos" && ${os_release} = "7" ]];then

		if [[ ${kernel_type} = '1' ]];then
			\cp ${workdir}/config/yum/CentOS7-kernel.repo /etc/yum.repos.d/CentOS-kernel.repo
			yum --enablerepo=elrepo-kernel install -y kernel kernel-devel
		else
			\cp ${workdir}/config/yum/CentOS7-elrepo.repo /etc/yum.repos.d/elrepo.repo
			yum --enablerepo=elrepo-kernel install -y kernel-lt kernel-lt-devel
		fi

    fi


	if [[ $? != '0' ]];then
		error_log "安装内核失败请检查"
		exit 1
	fi
	if [[ ${os_release} = '6' ]];then
		if [ ! -f "/boot/grub/grub.conf" ]; then
			echo -e "${error} /boot/grub/grub.conf not found, please check it."
			exit 1
		fi
		sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
	elif [[ ${os_release} = '7' || ${os_release} = '8' ]];then
		if [ ! -f "/boot/grub2/grub.cfg" ]; then
			echo -e "${error} /boot/grub2/grub.cfg not found, please check it."
			exit 1
		fi
		grub2-set-default 0
	fi
    input_option '是否重启系统' 'y' 'is_reboot'
    is_reboot=${input_value}
    if [[ ${is_reboot} = "y" || ${is_reboot} = "Y" ]]; then
        reboot
    else
        info_log "已经取消重启"
        exit 0
    fi
}
