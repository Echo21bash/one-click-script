#!/bin/bash

system_security_set(){
	###密码更改周期配置
	sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
	sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS 80/' /etc/login.defs
	sed -i 's/PASS_MIN_LEN.*/PASS_MIN_LEN 12/' /etc/login.defs
	sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE 15/' /etc/login.defs
	success_log "更新密码过期周期为90天。"
	if [[ `grep 'pam_pwquality.so' /etc/pam.d/system-auth 2>/dev/null` ]];then
		sed -i 's/password    requisite.*/password    requisite     pam_pwquality.so minlen=12 dcredit=-2 ucredit=-1 lcredit=-1 ocredit=-1 try_first_pass local_users_only retry=3 authtok_type=/' /etc/pam.d/system-auth
		success_log "更新密码复杂度策略"
		info_log "密码复杂度策略为最小长度12位，至少包含2个数字，1个大写字母，1个小写字母，1个特殊字符"
	fi
	if [[ `grep 'pam_cracklib.so' /etc/pam.d/system-auth 2>/dev/null` ]];then
		sed -i 's/password    requisite.*/password    requisite     pam_cracklib.so minlen=12 dcredit=-2 ucredit=-1 lcredit=-1 ocredit=-1 try_first_pass retry=3 type=/' /etc/pam.d/system-auth
		success_log "更新密码复杂度策略"
		info_log "密码复杂度策略为最小长度12位，至少包含2个数字，1个大写字母，1个小写字母，1个特殊字符"
	fi
	###ssh远程登录限制
	if [[ -z `grep 'pam_tally2.so' /etc/pam.d/sshd` ]];then
		sed -i '/#%PAM-1.0/aauth       required     pam_tally2.so  onerr=fail  deny=3  lock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/sshd
		success_log "更新本地登录失败策略"
		info_log "登录失败策略为登录失败3次锁定10分钟"
	else
		info_log "已经存在策略，已跳过。"
	fi
	###本地登陆限制
	if [[ -z `grep 'pam_tally2.so' /etc/pam.d/system-auth` ]];then
		sed -i '/#%PAM-1.0/aauth       required     pam_tally2.so  onerr=fail  deny=5  lock_time=300  even_deny_root  root_unlock_time=120' /etc/pam.d/system-auth
		success_log "更新远程登录失败策略"
		info_log "登录失败策略为登录失败3次锁定10分钟"
	else
		info_log "已经存在策略，已跳过。"
	fi	

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
	

	
	#锁定关键文件系统
	#chattr +i /etc/passwd
	#chattr +i /etc/inittab
	#chattr +i /etc/group
	#chattr +i /etc/shadow
	#chattr +i /etc/gshadow
	#/bin/mv /usr/bin/chattr /usr/bin/lock
	#success_log "完成系统关键文件锁定"
}
