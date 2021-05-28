#!/bin/bash

system_optimize_set(){

	###yum替换为阿里源
	[[ ! -f /etc/yum.repos.d/CentOS-Base.repo.backup ]] && cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

	if [[ ${os_release} < "7" ]];then
		if [[ ! -f /etc/yum.repos.d/epel.repo ]];then
			curl -sL -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo >/dev/null 2>&1
		fi
		if [[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]];then
			curl -sL -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo >/dev/null 2>&1
		fi
	else
		if [[ ! -f /etc/yum.repos.d/epel.repo ]];then
			curl -sL -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo >/dev/null 2>&1
		fi
		if [[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]];then
			curl -sL -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo >/dev/null 2>&1
		fi
	fi
	yum -y install bash-completion wget chrony vim sysstat net-tools >/dev/null 2>&1
	if [[ $? = 0 ]];then
		success_log "完成yum源优化,并安装必要的命令..."
	else
		error_log "yum源优化失败请检查网络!"
	fi
	
	###系统limit限制优化
	[[ ! -f /etc/security/limits.conf.bakup ]] && cp /etc/security/limits.conf /etc/security/limits.conf.bakup
	if [[ -z `grep '*                  -        nofile         1024000' /etc/security/limits.conf` ]];then
		echo '*                  -        nofile         1024000'>>/etc/security/limits.conf
	fi
		
	if [[ -z `grep '*                  -        nproc          65536' /etc/security/limits.conf` ]];then
		echo '*                  -        nproc          65536'>>/etc/security/limits.conf
	fi
	[[ -f /etc/security/limits.d/20-nproc.conf ]] && sed -i 's/*          soft    nproc     4096/*          soft    nproc     65536/' /etc/security/limits.d/20-nproc.conf
	ulimit -HSn 1024000
	
	if [ $? -eq 0 ];then
		success_log "完成最大进程数和最大打开文件数优化"
	else
		error_log "完成最大进程数和最大打开文件数优化"
	fi

	#Centos7对于systemd service的资源设置，则需修改全局配置，全局配置文件放在/etc/systemd/system.conf和/etc/systemd/user.conf，同时也会加载两个对应目录中的所有.conf文件/etc/systemd/system.conf.d/*.conf和/etc/systemd/user.conf.d/*.conf。system.conf是系统实例使用的，user.conf是用户实例使用的。
	if [[ -f /etc/systemd/system.conf ]];then
		[[ ! -f /etc/systemd/system.conf.bakup ]] && cp /etc/systemd/system.conf /etc/systemd/system.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=1024000/' /etc/systemd/system.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/system.conf
	fi
	if [[ -f /etc/systemd/user.conf ]];then
		[[ ! -f /etc/systemd/user.conf.bakup ]] && cp /etc/systemd/user.conf /etc/systemd/user.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=1024000/' /etc/systemd/user.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/user.conf
	fi

	###ssh连接速度优化
	[ ! -f /etc/ssh/sshd_config.bakup ] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bakup
	#sed -i 's/#Port 22/Port 52233/g' /etc/ssh/sshd_config
	sed -i 's/^#LogLevel INFO/LogLevel INFO/g' /etc/ssh/sshd_config
	sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
	#sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sed -i 's/^GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config 
	sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
	echo '+-------modify the sshd_config-------+'
	#echo 'Port 52233'
	echo 'LogLevel INFO'
	echo 'PermitEmptyPasswords no'
	#echo 'PermitRootLogin no'
	echo 'UseDNS no'
	echo '+------------------------------------+'
	if [[ ${os_release} < '7' ]];then
		/etc/init.d/sshd reload >/dev/null 2>&1 && success_log "完成SSHD服务优化" || error_log "SSHD服务优化失败"
	else
		systemctl restart sshd && success_log "完成SSHD服务优化" || error_log "SSHD服务优化失败"
	fi

	###系统时区配置为上海东八区，根据阿里云时钟进行时间同步
	rm -rf /etc/localtime
	ln -sfn /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	yum -y install chrony

	if [ $? -eq 0 ];then
		if [[ -z `grep time.pool.aliyun.com /etc/chrony.conf` ]];then
			sed -i '/# Please consider/aserver time.pool.aliyun.com' /etc/chrony.conf
			if [ $? -eq 0 ];then
				success_log "完成系统时区、时间同步配置"
			else
				error_log "时间同步配置失败"
			fi
		else
			success_log "完成系统时区、时间同步配置"
		fi

	fi
	
	###内核参数调整
	[ ! -f /etc/sysctl.conf.bakup ] && cp /etc/sysctl.conf /etc/sysctl.conf.bakup
	
	[[ -z `grep -E '^kernel.sem' /etc/sysctl.conf` ]] && echo 'kernel.sem = 500 1024000 200 4096'>>/etc/sysctl.conf
	#禁用ipv6
	[[ -z `grep -E '^net.ipv6.conf.all.disable_ipv6' /etc/sysctl.conf` ]] && echo 'net.ipv6.conf.all.disable_ipv6 = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv6.conf.default.disable_ipv6' /etc/sysctl.conf` ]] && echo 'net.ipv6.conf.default.disable_ipv6 = 1'>>/etc/sysctl.conf

	[[ -z `grep -E '^net.ipv4.tcp_fin_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_fin_timeout = 10'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_keepalive_time' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_keepalive_time = 600'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_tw_reuse' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_reuse = 1'>>/etc/sysctl.conf
	if [[ ${kel} < '4.12' ]];then
		[[ -z `grep -E '^net.ipv4.tcp_tw_recycle' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_recycle = 0'>>/etc/sysctl.conf
	fi
	[[ -z `grep -E '^net.ipv4.tcp_syncookies' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syncookies = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_syn_retries' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syn_retries = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.ip_local_port_range' /etc/sysctl.conf` ]] && echo 'net.ipv4.ip_local_port_range = 1025 65535'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_syn_backlog' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_syn_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.somaxconn' /etc/sysctl.conf` ]] && echo 'net.core.somaxconn = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_tw_buckets' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_tw_buckets = 1000'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.route.gc_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.route.gc_timeout = 100'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.netdev_max_backlog' /etc/sysctl.conf` ]] && echo 'net.core.netdev_max_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.max_map_count' /etc/sysctl.conf` ]] && echo 'vm.max_map_count = 262144'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.swappiness' /etc/sysctl.conf` ]] && echo 'vm.swappiness = 10'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.dirty_background_ratio' /etc/sysctl.conf` ]] && echo 'vm.dirty_background_ratio = 5'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.dirty_expire_centisecs' /etc/sysctl.conf` ]] && echo 'vm.dirty_expire_centisecs = 1500'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.dirty_ratio' /etc/sysctl.conf` ]] && echo 'vm.dirty_ratio = 20'>>/etc/sysctl.conf
	
	sysctl -p>/dev/null 2>&1
	success_log "完成内核参数调整"


	###关闭seliux关闭防火墙
	[ ! -f /etc/selinux/config.bakup ] && cp /etc/selinux/config /etc/selinux/config.bakup
	[[ ${os_release} < "7" ]] && /etc/init.d/iptables stop >/dev/null && chkconfig iptables off
	[[ ${os_release} > "6" ]] && systemctl stop firewalld.service && systemctl disable firewalld.service >/dev/null
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
	if [ ! -z `grep SELINUX=disabled /etc/selinux/config` ];then
		success_log "完成禁用selinux、关闭防火墙"
	else
		error_log "禁用selinux、关闭防火墙失败"
	fi


	if [[ ${os_release} < "7" ]];then
		for A in sysstat rsyslog network sshd crond chronyd;do chkconfig $A on;done
	else
		for A in sysstat rsyslog network sshd crond chronyd;do systemctl enable $A;done
	fi
	success_log "系统必要服务设置开机自启"

	###系统用户操作记录配置/var/log/bash_history.log
	cat >/etc/profile.d/bash_history.sh <<-'EOF'
	#!/bin/bash
	
	export HISTTIMEFORMAT="[%Y-%m-%d %H:%M:%S] [`who am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`] "
	export PROMPT_COMMAND='\
	if [ -z "$OLD_PWD" ];then
		export OLD_PWD=$(pwd);
	fi;
	if [ ! -z "$LAST_CMD" ] && [ "$(history 1)" != "$LAST_CMD" ]; then
		echo  `whoami`_shell_cmd "[$OLD_PWD]$(history 1)" >>/var/log/bash_history.log;
	fi;
	export LAST_CMD="$(history 1)";
	export OLD_PWD=$(pwd);'
	EOF
	[[ -z `grep 'TMOUT=600' /etc/profile` ]] && echo 'TMOUT=600' >> /etc/profile
	[[ ! -f /var/log/bash_history.log ]] && touch /var/log/bash_history.log
	chmod a+w /var/log/bash_history.log
	chmod +x /etc/profile.d/bash_history.sh
	source /etc/profile
	success_log "系统用户操作记录配置默认记录位置/var/log/bash_history.log"
	
	[[ -z `grep 'pam_tally2.so' /etc/pam.d/sshd` ]] && sed -i '/#%PAM-1.0/aauth       required     pam_tally2.so  onerr=fail  deny=3  lock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/sshd
	success_log "增加登录失败策略"
	
	#锁定关键文件系统
	#chattr +i /etc/passwd
	#chattr +i /etc/inittab
	#chattr +i /etc/group
	#chattr +i /etc/shadow
	#chattr +i /etc/gshadow
	#/bin/mv /usr/bin/chattr /usr/bin/lock
	#success_log "完成系统关键文件锁定"
}
