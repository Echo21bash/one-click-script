#!/bin/bash

system_optimize_set(){
	if [[ -z ${conf[@]} ]];then
		output_option "选择需要优化的项(可多选)" "替换为国内YUM源 优化最大限制 优化SSHD服务 系统时间同步 优化内核参数 关闭SElinux 关闭非必须服务 设置shell终端参数 锁定系统关键文件 全部优化" "conf"
	fi
	for conf in ${conf[@]}
	do
		case "$conf" in
			1)system_optimize_yum
			;;
			2)system_optimize_Limits
			;;
			3)system_optimize_sshd
			;;
			4)system_optimize_systime
			;;
			5)system_optimize_kernel
			;;
			6)system_optimize_selinux
			;;
			7)system_optimize_service
			;;
			8)system_optimize_profile
			;;
			9)system_optimize_permission
			;;
		esac
	done
}

system_optimize_yum(){
	
	[[ ! -f /etc/yum.repos.d/CentOS-Base.repo.backup ]] && cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

	if [[ ${os_release} < "7" ]];then
		[[ ! -f /etc/yum.repos.d/epel.repo ]] && \
		curl -sL -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo >/dev/null 2>&1
		[[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]] && \
		curl -sL -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo >/dev/null 2>&1
		yum clean all >/dev/null 2>&1
	else
		[[ ! -f /etc/yum.repos.d/epel.repo ]] && \
		curl -sL -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo >/dev/null 2>&1
		[[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]] && \
		curl -sL -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo >/dev/null 2>&1
		yum clean all >/dev/null 2>&1
	fi
	yum -y install bash-completion wget chrony vim >/dev/null 2>&1
	if [[ $? = 0 ]];then
		diy_echo "完成yum源优化,并安装必要的命令..." "" "${info}"
	else
		diy_echo "yum源优化失败请检查网络!" "" "${error}"
	fi
}

system_optimize_Limits(){

	LIMIT=`grep nofile /etc/security/limits.conf |grep -v "^#"|wc -l`
	if [ $LIMIT -eq 0 ];then
		[ ! -f /etc/security/limits.conf.bakup ] && cp /etc/security/limits.conf /etc/security/limits.conf.bakup
		echo '*                  -        nofile         65536'>>/etc/security/limits.conf
		echo '*                  -        nproc          65536'>>/etc/security/limits.conf
		[ -f /etc/security/limits.d/20-nproc.conf ] && sed -i 's/*          soft    nproc     4096/*          soft    nproc     65536/' /etc/security/limits.d/20-nproc.conf
		ulimit -HSn 65536
		if [ $? -eq 0 ];then
			diy_echo "完成最大进程数和最大打开文件数优化" "" "${info}"
		else
			diy_echo "完成最大进程数和最大打开文件数优化" "${red}" "${error}"
		fi
	fi
  #Centos7对于systemd service的资源设置，则需修改全局配置，全局配置文件放在/etc/systemd/system.conf和/etc/systemd/user.conf，同时也会加载两个对应目录中的所有.conf文件/etc/systemd/system.conf.d/*.conf和/etc/systemd/user.conf.d/*.conf。system.conf是系统实例使用的，user.conf是用户实例使用的。
	if [[ -f /etc/systemd/system.conf ]];then
		[[ ! -f /etc/systemd/system.conf.bakup ]] && cp /etc/systemd/system.conf /etc/systemd/system.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65536/' /etc/systemd/system.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/system.conf
	fi
	if [[ -f /etc/systemd/user.conf ]];then
		[[ ! -f /etc/systemd/user.conf.bakup ]] && cp /etc/systemd/user.conf /etc/systemd/user.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65536/' /etc/systemd/user.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/user.conf
	fi
}

system_optimize_sshd(){

	[ ! -f /etc/ssh/sshd_config.bakup ] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bakup
	sed -i 's/#Port 22/Port 52233/g' /etc/ssh/sshd_config
	sed -i 's/^#LogLevel INFO/LogLevel INFO/g' /etc/ssh/sshd_config
	sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
	#sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sed -i 's/^GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config 
	sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
	echo '+-------modify the sshd_config-------+'
	echo 'Port 52233'
	echo 'LogLevel INFO'
	echo 'PermitEmptyPasswords no'
	#echo 'PermitRootLogin no'
	echo 'UseDNS no'
	echo '+------------------------------------+'
	if [[ ${os_release} < '7' ]];then
		/etc/init.d/sshd reload >/dev/null 2>&1 && diy_echo "完成SSHD服务优化" "" "${info}" || diy_echo "SSHD服务优化失败" "" "${error}"
	else
		systemctl restart sshd && diy_echo "完成SSHD服务优化" "" "${info}" || diy_echo "SSHD服务优化失败" "" "${error}"
	fi
}

system_optimize_systime(){
	rm -rf /etc/localtime
	ln -sfn /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	yum -y install chrony

	if [ $? -eq 0 ];then
		if [[ -z `grep time.pool.aliyun.com /etc/chrony.conf` ]];then
			sed -i '/# Please consider/aserver time.pool.aliyun.com' /etc/chrony.conf
			if [ $? -eq 0 ];then
				diy_echo "完成时间同步配置" "" "${info}"
			else
				diy_echo "时间同步配置失败" "" "${error}"
			fi
		fi

	fi
}

system_optimize_kernel(){
	[ ! -f /etc/sysctl.conf.bakup ] && cp /etc/sysctl.conf /etc/sysctl.conf.bakup
	[[ -z `grep -E '^net.ipv4.tcp_fin_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_fin_timeout = 10'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_keepalive_time' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_keepalive_time = 600'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_tw_reuse' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_reuse = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_tw_recycle' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_recycle = 0'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_syncookies' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syncookies = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_syn_retries' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syn_retries = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.ip_local_port_range' /etc/sysctl.conf` ]] && echo 'net.ipv4.ip_local_port_range = 4000 65000'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_syn_backlog' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_syn_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.somaxconn' /etc/sysctl.conf` ]] && echo 'net.core.somaxconn = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_tw_buckets' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_tw_buckets = 36000'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.route.gc_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.route.gc_timeout = 100'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.netdev_max_backlog' /etc/sysctl.conf` ]] && echo 'net.core.netdev_max_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.max_map_count' /etc/sysctl.conf` ]] && echo 'vm.max_map_count = 262144'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.swappiness' /etc/sysctl.conf` ]] && echo 'vm.swappiness = 0'>>/etc/sysctl.conf

	sysctl -p>/dev/null 2>&1
	diy_echo "完成内核参数调整" "" "${info}"

}

system_optimize_selinux(){

	[ ! -f /etc/selinux/config.bakup ] && cp /etc/selinux/config /etc/selinux/config.bakup
	[[ ${os_release} < "7" ]] && /etc/init.d/iptables stop >/dev/null
	[[ ${os_release} > "6" ]] && systemctl stop firewalld.service >/dev/null
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
	if [ ! -z `grep SELINUX=disabled /etc/selinux/config` ];then
		diy_echo "完成禁用selinux、关闭防火墙" "" "${info}"
	else
		diy_echo "禁用selinux、关闭防火墙失败" "" "${error}"
	fi
}

system_optimize_service(){

	if [[ ${os_release} < "7" ]];then
		for A in `chkconfig --list |grep -E '3:on|3:启用' |awk '{print $1}' `
		do
			chkconfig $A off
		done
		for A in rsyslog network sshd crond chronyd;do chkconfig $A on;done
	else
		for A in `systemctl list-unit-files|grep enabled |awk '{print $1}'`
		do
			systemctl disable $A >/dev/null
		done
		for A in rsyslog network sshd crond chronyd;do systemctl enable $A;done
	fi
	diy_echo "精简开机自启动完成" "" "${info}"
}

system_optimize_profile(){

	if [ -z `grep TMOUT=600 /etc/profile` ];then
		echo "TMOUT=600" >>/etc/profile
		echo "HISTSIZE=10" >>/etc/profile
		echo "HISTFILESIZE=10" >>/etc/profile
		source /etc/profile
		diy_echo "完成历史记录数和连接超时时间调整" "" "${info}"
	fi
}

system_optimize_permission(){
	#锁定关键文件系统
	chattr +i /etc/passwd
	chattr +i /etc/inittab
	chattr +i /etc/group
	chattr +i /etc/shadow
	chattr +i /etc/gshadow
	/bin/mv /usr/bin/chattr /usr/bin/lock
	diy_echo "完成系统关键文件锁定" "" "${info}"
}
