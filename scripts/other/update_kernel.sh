#!/bin/bash
update_kernel(){
	warning_log "请谨慎更新内核,需要重新系统"
	output_option '选择升级kernel类型' '长期维护版 最新版' 'kernel_type'
	if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
		rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
		if (( ${os_release} < '7' ));then
			rpm -Uvh http://www.elrepo.org/elrepo-release-6-8.el6.elrepo.noarch.rpm
		elif (( ${os_release} >= '7' ));then
			rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
		fi
	fi

	if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
		error_log "添加elrepo源失败"
		exit 1
	fi
	if [[ ${kernel_type} = '1' ]];then
		yum --enablerepo=elrepo-kernel install -y kernel-lt kernel-lt-devel
	else
		yum --enablerepo=elrepo-kernel install -y kernel-ml kernel-ml-devel
	fi
	if [[ $? != '0' ]];then
		error_log "安装内核失败请检查"
		exit 1
	fi
	if [[ ${os_release} < '7' ]];then
		if [ ! -f "/boot/grub/grub.conf" ]; then
			echo -e "${error} /boot/grub/grub.conf not found, please check it."
			exit 1
		fi
		sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
	elif [[ ${os_release} > '6' ]];then
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
