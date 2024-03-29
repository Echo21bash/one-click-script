#!/bin/bash

system_security_set(){
	###密码更改周期配置
	[[ ! -f /etc/login.defs.default ]] && cp /etc/login.defs /etc/login.defs.default
	sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
	sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS 80/' /etc/login.defs
	sed -i 's/PASS_MIN_LEN.*/PASS_MIN_LEN 12/' /etc/login.defs
	sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE 15/' /etc/login.defs
	success_log "更新密码过期周期为90天。"
	
	###密码复杂度配置
	[[ ! -f /etc/pam.d/system-auth.default ]] && cp /etc/pam.d/system-auth /etc/pam.d/system-auth.default
	if [[ `grep 'pam_pwquality.so' /etc/pam.d/system-auth 2>/dev/null` ]];then
		sed -i 's/password    requisite.*/password    requisite     pam_pwquality.so minlen=12 dcredit=-2 ucredit=-1 lcredit=-1 ocredit=-1 enforce_for_root try_first_pass local_users_only retry=3 authtok_type=/' /etc/pam.d/system-auth
		success_log "更新密码复杂度策略"
		info_log "密码复杂度策略为最小长度12位，至少包含2个数字，1个大写字母，1个小写字母，1个特殊字符"
	fi
	if [[ `grep 'pam_cracklib.so' /etc/pam.d/system-auth 2>/dev/null` ]];then
		sed -i 's/password    requisite.*/password    requisite     pam_cracklib.so minlen=12 dcredit=-2 ucredit=-1 lcredit=-1 ocredit=-1 enforce_for_root try_first_pass retry=3 type=/' /etc/pam.d/system-auth
		success_log "更新密码复杂度策略"
		info_log "密码复杂度策略为最小长度12位，至少包含2个数字，1个大写字母，1个小写字母，1个特殊字符"
	fi

	###登录失败配置
	if [[  ${sys_name} = "Centos" ]];then
		###ssh远程登录限制
		[[ ! -f //etc/pam.d/sshd.default ]] && cp /etc/pam.d/sshd /etc/pam.d/sshd.default
		if [[ -z `grep 'pam_tally2.so' /etc/pam.d/sshd` ]];then
			sed -i '/#%PAM-1.0/aauth       required     pam_tally2.so  onerr=fail  deny=3  unlock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/sshd
			success_log "更新远程登录失败策略"
			info_log "登录失败策略为登录失败3次锁定10分钟"
		else
			info_log "已经存在策略，已跳过。"
		fi
		###本地登陆限制
		[[ ! -f /etc/pam.d/system-auth.default ]] && cp /etc/pam.d/system-auth /etc/pam.d/system-auth.default
		if [[ -z `grep 'pam_tally2.so' /etc/pam.d/system-auth` ]];then
			sed -i '/#%PAM-1.0/aauth       required     pam_tally2.so  onerr=fail  deny=5  unlock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/system-auth
			success_log "更新本地登录失败策略"
			info_log "登录失败策略为登录失败3次锁定10分钟"
		else
			info_log "已经存在策略，已跳过。"
		fi	
	fi

	if [[  ${sys_name} = "openEuler" ]];then
		###ssh远程登录限制
		[[ ! -f /etc/pam.d/sshd.default ]] && cp /etc/pam.d/sshd /etc/pam.d/sshd.default
		if [[ -z `grep 'pam_faillock.so' /etc/pam.d/sshd` ]];then
			sed -i '/#%PAM-1.0/aauth       required     pam_faillock.so deny=3  unlock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/sshd
			success_log "更新远程登录失败策略"
			info_log "登录失败策略为登录失败3次锁定10分钟"
		else
			info_log "已经存在策略，已跳过。"
		fi
		###本地登陆限制
		[[ ! -f /etc/pam.d/system-auth.default ]] && cp /etc/pam.d/system-auth /etc/pam.d/system-auth.default
		if [[ -z `grep 'pam_faillock.so' /etc/pam.d/system-auth` ]];then
			sed -i '/#%PAM-1.0/aauth       required     pam_faillock.so deny=5  unlock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/system-auth
			success_log "更新本地登录失败策略"
			info_log "登录失败策略为登录失败3次锁定10分钟"
		else
			info_log "已经存在策略，已跳过。"
		fi	
	fi
	###系统用户操作记录
	cat >/etc/profile.d/bash_history.sh <<-'EOF'
	#!/bin/bash
	export HISTTIMEFORMAT="[%Y-%m-%d %H:%M:%S] [`who am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`] "
	export PROMPT_COMMAND='\
	if [ -z "$OLD_PWD" ];then
	    export OLD_PWD=$(pwd);
	fi;
	if [ ! -z "$LAST_CMD" ] && [ "$(history 1)" != "$LAST_CMD" ]; then
	    logger -t `whoami`_shell_cmd "[$OLD_PWD]$(history 1)";
	fi;
	export LAST_CMD="$(history 1)";
	export OLD_PWD=$(pwd);'
	EOF
	[[ ! -f /etc/profile.default ]] && cp /etc/profile /etc/profile.default
	[[ -z `grep 'TMOUT=600' /etc/profile` ]] && echo 'TMOUT=600' >> /etc/profile

	source /etc/profile
	success_log "系统用户操作记录配到到/var/log/messages"
	
	if [[ -z `grep '^Banner' /etc/ssh/sshd_config` ]];then
		sed -i '/#Banner none/aBanner /etc/ssh/alert' /etc/ssh/sshd_config
		cat >/etc/ssh/alert<<-EOF
		*******************************************************
		警告!!!你已经登录生产环境,一切操作将被记录请谨慎操作!!!
		Warning!!!Any Access Without Permission Is Forbidden!!!
		*******************************************************
		EOF
		success_log "添加ssh登陆Banner"
	else
		info_log "ssh登陆Banner，已跳过。"
	fi
	
	if [[ -z `grep '^umask 027' /etc/profile` ]];then
		echo "umask 027" >>/etc/profile
		success_log "文件掩码umask修改为027"
	fi
	
	if [[ -z `grep '^umask 027' /etc/bashrc` ]];then
		echo "umask 027" >>/etc/bashrc
		success_log "文件掩码umask修改为027"
	fi
	
	###control-alt-delete组合键禁用
	if [[ -f /etc/init/control-alt-delete.conf ]];then
		sed -i 's?exec /sbin/shutdown?#exec /sbin/shutdown?' /etc/init/control-alt-delete.conf
		if [[ -f /usr/lib/systemd/system/ctrl-alt-del.target ]];then
			\cp /usr/lib/systemd/system/ctrl-alt-del.target /usr/lib/systemd/system/ctrl-alt-del.target.default
			rm -rf /usr/lib/systemd/system/ctrl-alt-del.target
		fi
	fi
	###系统日志轮转
	if [[ -f /etc/logrotate.conf ]];then
		[[ ! -f /etc/logrotate.conf.default ]] && cp /etc/logrotate.conf /etc/logrotate.conf.default
		sed -i 's/^rotate.*/rotate 26/' /etc/logrotate.conf
		success_log "系统日志轮转周期修改为26周"
	fi
	if [[ ! -f /etc/logrotate.d/audit && -f /var/log/audit/audit.log ]];then
		add_log_cut /etc/logrotate.d/audit /var/log/audit/audit.log
	fi
	service_control auditd enable
	service_control auditd start
	service_control rsyslog enable
	service_control rsyslog start
	service_control chronyd enable
	service_control chronyd start

	#锁定关键文件系统
	#chattr +i /etc/passwd
	#chattr +i /etc/inittab
	#chattr +i /etc/group
	#chattr +i /etc/shadow
	#chattr +i /etc/gshadow
	#/bin/mv /usr/bin/chattr /usr/bin/lock
	#success_log "完成系统关键文件锁定"
}
