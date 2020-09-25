#!/bin/bash

add_sysuser(){
	echo -e "${info} Start adding system users"
	while true
	do
		read -p "Please enter a new username:" name
		NAME=`awk -F':' '{print $1}' /etc/passwd|grep -wx $name 2>/dev/null|wc -l`
		if [[ ${name} = '' ]];then
		echo -e "${error} Username cannot be empty, please re-enter"
		continue
	elif [ $NAME -eq 1 ];then
		echo -e "${error} User name already exists, please re-enter"
		continue
	fi
	useradd ${name}
	if [ $? = '0' ];then
		echo -e "${info} Added system user success"
	else
		echo -e "${error} Failed to add system user"
		exit
    fi
	break
	done
	#create password
	while true
	do
		read -p "Create a password for $name:" pass1
		if [ ${#pass1} -eq 0 ];then
			echo "Password cannot empty please re-enter"
			continue
		fi
		read -p "Please enter your password again:" pass2
		if [ "$pass1" != "$pass2" ];then
			echo "The password input is not the same, please re-enter"
			continue
		fi
		echo "$pass2" | passwd --stdin $name
		if [ $? = '0' ];then
			echo -e "${info} Create a password for $name success"
		else
			echo -e "${error} Failed to create a password for $name"
			exit
		fi
		break
	done
	sleep 1
}

#日志切割
add_log_cut(){
	#$1生成日志切割配置模板路径 $2日志文件路径
	log_cut_config_file=$1
	logs_dir=$2
	if [[ -z ${logs_dir} ]];then
		error_log "函数add_log_cut缺少参数\$2(日志文件路径)"
		exit 1
	fi
	if [[ -n ${log_cut_config_file} ]];then
		pdir=`dirname ${log_cut_config_file}`
		if [[ ! -d ${pdir} ]];then
			mkdir -p ${pdir}
		fi
		cat >${log_cut_config_file}<<-EOF
		${logs_dir}{
		daily
		rotate 15
		missingok
		notifempty
		copytruncate
		dateext
		}
		EOF
		success_log "成功创建${log_cut_config_file}日志切割配置文件,请复制到/etc/rsyslog.d/下"
	else
		error_log "函数add_log_cut缺少参数\$1(日志切割配置模板路径)"
		exit 1
	fi

}
#守护进程配置
conf_system_service(){
	#$1生成系统服务配置模板路径
	system_service_config_file=$1
	if [[ -n ${system_service_config_file} ]];then
		pdir=`dirname ${system_service_config_file}`
		if [[ ! -d ${pdir} ]];then
			mkdir -p ${pdir}
		fi
	else
		error_log "函数conf_system_service缺少参数\$1(生成系统服务配置模板路径)"
		exit 1
	fi
	if [[ -z ${ExecStart} ]];then
		error_log "函数conf_system_service函数缺少ExecStart变量"
		exit 1
	fi
	if [[ -z ${init_dir} ]];then
		init_dir=${home_dir}
	fi
	#必传参数ExecStart
	if [[ "${os_release}" -lt 7 ]]; then
		cat >${system_service_config_file}<<-EOF
		#!/bin/bash
		# chkconfig: 345 70 60
		# description: ${soft_name} daemon
		# processname: ${soft_name}

		EnvironmentFile="${EnvironmentFile:-}"
		Environment="${Environment:-}"
		Name="${Name:-${soft_name}}"
		PidFile="${PidFile:-}"
		User="${User:-root}"
		ExecStart="${ExecStart:-}"
		ARGS="${ARGS:-}"
		ExecStop="${ExecStop:-}"
		EOF
		cat >>${system_service_config_file}<<-'EOF'
		#EUV
		[[ -f ${EnvironmentFile} ]] && . ${EnvironmentFile}
		[[ -f ${Environment} ]] && export ${Environment}
		_pid(){
		  [[ -s $PidFile ]] && pid=$(cat $PidFile) && kill -0 $pid 2>/dev/null || pid=''
		  [[ -z $PidFile ]] && pid=$(ps aux | grep ${ExecStart} | grep -v grep | awk '{print $2}')
		}

		_start(){
		  _pid
		  if [ -n "$pid" ];then
		    echo -e "\e[00;32m${Name} is running with pid: $pid\e[00m"
		  else
		    echo -e "\e[00;32mStarting ${Name}\e[00m"
		    id -u ${User} >/dev/null
		    if [ $? = 0 ];then
		      su ${User} -c "${ExecStart} ${ARGS} &"
		    fi
		    _status
		  fi
		}

		_stop(){
		  _pid
		  if [ -n "$pid" ]; then
		    [[ -n "${ExecStop}" ]] && ${ExecStop}
		    [[ -z "${ExecStop}" ]] && kill $pid
		    for ((i=1;i<=5;i++));
		    do
		      _pid
		      if [ -n "$pid" ]; then
		        echo -n -e "\e[00;31mWaiting for the program to exit\e[00m\n";
		        sleep 3
		      else
		        echo -e "\e[00;32m${Name} stopped successfully\e[00m" && break
		      fi
		    done
		    _pid
		    if [ -n "$pid" ]; then
		        kill -9 $pid && echo -e "\033[0;33m${Name} process is being forced to shutdown...(pid:$pid)\e[00m"
		    fi
		  else
		    echo -e "\e[00;31m${Name} is not running\e[00m"
		  fi
		}

		_status(){
		  _pid
		  if [ -n "$pid" ]; then
		    echo -e "\e[00;32m${Name} is running with pid: $pid\e[00m"
		  else 
		    echo -e "\e[00;31m${Name} is not running\e[00m"
		  fi
		}
		_usage(){
		  echo -e "Usage: $0 {\e[00;32mstart\e[00m|\e[00;31mstop\e[00m|\e[00;32mstatus\e[00m|\e[00;31mrestart\e[00m}"
		}
		case $1 in
		    start)
		    _start
		    ;;
		    stop)
		    _stop
		    ;;   
		    restart)
		    _stop
		    sleep 3
		    _start
		    ;;
		    status)
		    _status
		    ;;
		    *)
		    _usage
		    ;;
		esac
		EOF
		success_log "成功创建${system_service_config_file}系统服务配置文件,请复制到/etc/init.d/下"
	elif [[ "${os_release}" -ge 7 ]]; then
		cat >${system_service_config_file}<<-EOF
		[Unit]
		Description=${soft_name}
		After=syslog.target network.target

		[Service]
		Type=${Type:-simple}
		User=${User:-root}

		EnvironmentFile=${EnvironmentFile:-}
		Environment=${Environment:-}

		WorkingDirectory=${WorkingDirectory:-}
		PIDFile=${PIDFile:-}
		ExecStart=${ExecStart:-} ${ARGS:-}
		ExecStartPost=${ExecStartPost:-}
		ExecReload=${ExecReload:-/bin/kill -s HUP \$MAINPID}
		ExecStop=${ExecStop:-/bin/kill -s QUIT \$MAINPID}
		TimeoutStopSec=5
		Restart=${Restart:-on-failure}
		LimitNOFILE=65536
		[Install]
		WantedBy=multi-user.target
		EOF
		success_log "成功创建${system_service_config_file}系统服务配置文件,请复制到/etc/systemd/system/下"
	fi
	#删除空值
	[[ -z ${WorkingDirectory} ]] && sed -i /WorkingDirectory=/d ${system_service_config_file}
	[[ -z ${Environment} ]] && sed -i /Environment=/d ${system_service_config_file}
	[[ -z ${EnvironmentFile} ]] && sed -i /EnvironmentFile=/d ${system_service_config_file}
	[[ -z ${PIDFile} ]] && sed -i /PIDFile=/d ${system_service_config_file}
	[[ -z ${ExecStartPost} ]] && sed -i /ExecStartPost=/d ${system_service_config_file}

}
#添加守护进程
add_system_service(){
	#$1服务名 $2服务文件路径 $3现在启动
	service_name=$1
	service_file_dir=$2
	start_arg=$3
	if [[ "${os_release}" < '7' ]]; then
		if [[ -f /etc/init.d/${service_name} ]];then
			input_option "已经存在服务名${service_name},请重新设置服务名称(可覆盖)" "${service_name}" 'service_name'
			service_name=${input_value}
		fi
		\cp ${service_file_dir} /etc/init.d/${service_name}
	elif [[ "${os_release}" > '6' ]]; then
		if [[ -f /etc/systemd/system/${service_name}.service ]];then
			input_option "已经存在服务名${service_name},请重新设置服务名称(可覆盖)" "${service_name}" 'service_name'
			service_name=${input_value}
		fi
		\cp ${service_file_dir} /etc/systemd/system/${service_name}.service
	fi
	service_control
}

service_control(){
	if [[ "x$1" != 'x' ]];then
		service_name=$1
	fi
	if [[ ${os_release} -lt '7' ]];then
		chmod +x /etc/init.d/${service_name}
		chkconfig --add /etc/init.d/${service_name}
		echo -e "${info} ${service_name} command: $(diy_echo "service ${service_name} start|stop|restart|status" "$yellow")"
		[[ ${start_arg} = 'y' ]] && service ${service_name} start && diy_echo "${service_name}启动完成." "" "${info}"
	fi

	if [[  ${os_release} -ge '7' ]];then
		systemctl daemon-reload
		systemctl enable ${service_name} >/dev/null
		echo -e "${info} ${service_name} command: $(diy_echo "systemctl start|stop|restart|status ${service_name}" "$yellow")"
		[[ ${start_arg} = 'y' ]] && systemctl start ${service_name} && diy_echo "${service_name}启动完成." "" "${info}"
	fi
}
#添加环境变量
add_sys_env(){
 
	if [[ -n $1 ]];then
		option=($1)
		for item in ${option[@]}
		do
			cat >>/etc/profile.d/${soft_name}.sh<<-EOF
			export $item
			EOF
		done
		chmod +x /etc/profile.d/${soft_name}.sh
		source /etc/profile.d/${soft_name}.sh
	fi
	diy_echo "请再运行一次source /etc/profile" "${yellow}" "${info}"
}
