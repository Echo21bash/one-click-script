#!/bin/bash
###########################################################
#System Required: Centos 6+
#Description: Install the java tomcat mysql and tools
#Version: 2.0
#                                                        
#                            by---wang2017.7
###########################################################

###pubic函数
colour_keyword(){
	red='\033[0;31m'
	green='\033[0;32m'
	yellow='\033[0;33m'
	plain='\033[0m'
	info="[${green}INFO${plain}]"
	warning="[${yellow}WARNING${plain}]"
	error="[${red}ERROR${plain}]"
}

info_log(){
	echo -e "[${green}INFO${plain}] ${green}➜ $@ ${plain}"
}

error_log(){
	echo -e "[${red}ERROR${plain}] ${red}✖ $@ ${plain}"
}

warning_log(){
	echo -e "[${yellow}WARNING${plain}] ${yellow}⚠ $@ ${plain}"
}

success_log(){
	echo -e "[${green}SUCCESS${plain}] ${green}✔ $@ ${plain}"
}

diy_echo(){
	#$1内容 $2颜色(非必须) $3前缀关键字(非必须)
	if [[ $# = '3' ]];then
		echo -e "$3 $2$1${plain}"
	fi
	
	if [[ $# = '2' ]];then
		if [[ $2 =~ 'INFO' || $2 =~ 'WARNING' || $2 =~ 'ERROR' ]];then
			echo -e "$2 $1${plain}"
		else
			echo -e "$2$1${plain}"
		fi
	fi
	if [[ $# = '1' ]];then
		echo -e "$1"
	fi
}

yes_or_no(){
	#$1变量值
	tmp=$(echo $1 | tr [A-Z] [a-z])
	if [[ $tmp = 'y' || $tmp = 'yes' ]];then
		return 0
	else
		return 1
	fi

}

input_option(){
	#$1输入描述、$2默认值(支持数组)、$3变量名
	#input_option '选项描述' '默认值' '变量名'
	#变量值为数字可直接使用传入的变量名，若为包含字符需要用${input_value[@]}变量中转否则会被转为0
	diy_echo "$1" "" "${info}"
	stty erase '^H' && read -t 30 -p "请输入(30s后选择默认$2):" input_value
	#变量数组化
	if [[ -z $input_value ]];then
		input_value=(${2})
	else
		input_value=(${input_value})
	fi
	length=${#input_value[@]}

	only_allow_numbers ${input_value[@]}
	if [[ $? = 0 ]];then
		#对数组赋值
		local i
		i=0
		for dd in ${input_value[@]}
		do
			(($3[$i]="$dd"))
			((i++))
		done
	fi
	a=${input_value[@]}
	diy_echo "你的输入是 $(diy_echo "${a}" "${green}")" "" "${info}"
}

output_option(){
	#第一个参数为选项描述，最后一个参数为变量名，中间为选项
	#选项支持数组和以空格隔开的字符串
	#输出选项
	diy_echo "$1" "" "${info}"
	#所有参数转化为数组
	all_option=($@)
	#数组长度
	len=${#all_option[@]}
	#数组最后一项内容
	last_option=${all_option[@]: -1}
	#最后一个下标号
	last_option_subscript=$((($len-1)))

	local i
	local j
	i=0
	j=0
	for item in ${all_option[@]}
	do
		if [[ $i -gt 0 && $i -lt $last_option_subscript ]];then
			#选项数组
			item_option[$j]=${all_option[$i]}
			((j++))
 			diy_echo "[${green}${j}${plain}] ${item}"
		fi
		((i++))
	done

	#清空output
	output=()
	stty erase '^H' && read -t 30 -p "请输入数字(30s后选择默认1):" output
	if [[ -z ${output} ]];then
		output=1
	fi

	output=(${output})
	#选项总数
	item_option_len=${#item_option[@]}
	#判断输入类型
	only_allow_numbers ${output[@]}
	if [[ $? != '0' ]];then
		error_log "输入值存在非数字"
		exit 1
	fi
	#清空output_value
	output_value=()
	local k
	k=0
	for item in ${output[@]}
	do	
		#选项数组
		if [[ $item -gt ${item_option_len} ]];then
			error_log "输入值大于选项总数"
			exit 1
		fi
		(($last_option[$k]=$item))
		((item--))
		#选项对应内容数组
		output_value[$k]=${item_option[$item]}
		((k++))
	done
	a=${output_value[@]}
	diy_echo "你的选择是 $(diy_echo "${a}" "${green}")"

}

only_allow_numbers(){
	#判断纯数字正确返回0
	#支持多个字符
	local j=0
	for ((j=0;j<$#;j++))
	do
		tmp=($@)
		if [[ -z "$(echo ${tmp[$j]} | sed 's#[0-9]##g')" ]];then
			continue
		else
			return 1
		fi
	done
}

sys_info(){

	if [ -f /etc/redhat-release ]; then
		if cat /etc/redhat-release | grep -Eqi "Centos";then
			sys_name="Centos"
		elif cat /etc/redhat-release | grep -Eqi "red hat" || cat /etc/redhat-release | grep -Eqi "redhat";then
			sys_name="Red-hat"
		fi
    elif cat /etc/issue | grep -Eqi "debian"; then
        sys_name="Debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        sys_name="Ubuntu"
    elif cat /etc/issue | grep -Eqi "Centos"; then
        sys_name="Centos"
    elif cat /etc/issue | grep -Eqi "red hat|redhat"; then
        sys_name="Red-hat"
	fi
	#版本号
    if [[ -s /etc/redhat-release ]]; then
		release_all=`grep -oE  "[0-9.0-9]+" /etc/redhat-release`
		os_release=${release_all%%.*}
		else
		release_all=`grep -oE  "[0-9.]+" /etc/issue`
		os_release=${release_all%%.*}
    fi
	#系统位数
	os_bit=`getconf LONG_BIT`
	#总内存MB
	total_mem=`free -m | grep -i Mem | awk '{print $2}'`
	#总核心数
	total_core=`cat /proc/cpuinfo | grep "processor"| wc -l`	
	#内核版本
	kel=`uname -r | grep -oE [0-9]{1}.[0-9]{1,\}.[0-9]{1,\}-[0-9]{1,\}`
	http_code=`curl -k -I -m 10 -o /dev/null -s -w %{http_code} www.baidu.com`
	if [ ${http_code} = '200' ];then
		network_status="${green}connected${plain}"
	else
		network_status="${red}disconnected${plain}"
	fi
	diy_echo "Your machine is:${sys_name}"-"${release_all}"-"${os_bit}-bit.\n${info} The kernel version is:${kel}.\n${info} Network status:${network_status}" "" "${info}"
	[[ ${sys_name} = "red-hat" ]] && sys_name="Centos"

}

get_ip(){
	local_ip=$(ip addr | grep -E 'eth[0-9a-z]{1,3}|eno[0-9a-z]{1,3}|ens[0-9a-z]{1,3}|enp[0-9a-z]{1,3}' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v  "^255\.|\.255$|^127\.|^0\." | head -n 1)
}

get_public_ip(){
	public_ip=$(curl ipv4.icanhazip.com)
}

get_net_name(){
	net_name=$(ip addr | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v  "^255\.|\.255$|^127\.|^0\." | grep -oE 'eth[0-9a-z]{1,3}|eno[0-9a-z]{1,3}|ens[0-9a-z]{1,3}|enp[0-9a-z]{1,3}' | head -n 1)
}

sys_info_detail(){
	sys_info
	#系统开机时间
	echo -e "${info} System boot time:"
	date -d "$(awk '{printf("%d\n",$1~/./?int($1)+1:$1)}' /proc/uptime) second ago" +"%F %T"
	#系统已经运行时间
	echo -e "${info} The system is already running:"
	awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60}{printf("%d天%d时%d分%d秒\n",a,b,c,d)}' /proc/uptime
	#CPU型号
	echo -e "${info} CPU型号:"
	awk -F':[ ]' '/model name/{printf ("%s\n",$2);exit}' /proc/cpuinfo
	#CPU详情
	echo -e "${info} CPU详情:"
	awk -F':[ ]' '/physical id/{a[$2]++}END{for(i in a)printf ("%s号CPU\t核心数:%s\n",i+1,a[i]);printf("CPU总颗数:%s\n",i+1)}' /proc/cpuinfo
	#ip
	echo -e "${info} 内网IP:"
	hostname -I 2>/dev/null
	[[ $? != "0" ]] && hostname -i
	echo -e "${info} 网关:"
	netstat -rn | awk '/^0.0.0.0/ {print $2}'
	echo -e "${info} 外网IP:"
	curl -s icanhazip.com
	#内存使用情况
	echo -e "${info} 内存使用情况(MB):参考[可用内存=free的内存+cached的内存+buffers的内存]"
	free -m
	(( ${os_release} < "7" )) && free -m | grep -i Mem | awk '{print "总内存是:"$2"M,实际使用内存是:"$2-$4-$5-$6-$7"M,实际可用内存是:"$4+$6+$7"M,内存使用率是:"(1-($4+$6+$7)/$2)*100"%"}' 
	(( ${os_release} >= "7" )) && free -m | grep -i Mem | awk '{print "总内存是:"$2"M,实际使用内存是:"$2-$4-$5-$6"M,实际可用内存是:"$4+$6"M,内存使用率是:"(1-($4+$6)/$2)*100"%"}'
	free -m | grep -i Swap| awk '{print "总Swap大小:"$2"M,已使用的大小:"$3"M,可用大小:"$4"M,Swap使用率是:"$3/$2*100"%"}' 
	#磁盘使用情况
	echo -e "${info} 磁盘使用情况:"
	df -h
	#服务器负载情况
	echo -e "${info} 服务器平均负载:"
	uptime | awk '{print $(NF-4)" "$(NF-3)" "$(NF-2)" "$(NF-2)" "$NF}'
	#当前在线用户
	echo -e "${info} 当前在线用户:"
	who
}


down_file(){
	github_mirror=(https://ghproxy.com https://github.wuyanzheshui.workers.dev https://hub.fastgit.org https://download.fastgit.org https://github.com.cnpmjs.org)
	#$1下载链接、$2保存已存在的路径或路径+名称
	if [[ -n $1 && -n $2 ]];then
		down_url=$1
		path_file=$2
		if [[ x`echo ${down_url} | grep -o github` = 'xgithub' ]];then
			#对github连接尝试使用镜像地址
			for mirror in ${github_mirror[@]};
			do
				mirror_status=`curl -I -m 10 -o /dev/null -s -w %{http_code} ${mirror}`
				if [[ ${mirror_status} = '200' ]];then
					if [[ ${mirror} = 'https://ghproxy.com' ]];then
						mirror_down_url="${mirror}/${down_url}"
					else
						mirror_down_url="${mirror}/${down_url#*github.com/}"
					fi
					break
				fi
			done
		fi
		#获取下载完成路径及文件名
		if [[ -d ${path_file} ]];then
			if [[ -z ${down_file_name} ]];then
				down_file_name=${down_url##*/}
			fi
			full_path_file=${path_file}/${down_file_name}
		else
			full_path_file=${path_file}
		fi
		#开始下载	
		if [[ ! -f ${full_path_file} && ! -f ${full_path_file}.st ]];then
			diy_echo "正在下载${down_url}" "${info}"
			if [[ -n ${mirror_down_url} ]];then
				axel -n 16 -a ${mirror_down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}" "${error}"
					exit 1
				fi
			else
				axel -n 16 -a ${down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}" "${error}"
					exit 1
				fi
			fi
		elif [[ -f ${full_path_file} && -f ${full_path_file}.st ]];then
			diy_echo "正在断点续传下载${down_url}" "${info}"
			if [[ -n ${mirror_down_url} ]];then
				axel -n 16 -a ${mirror_down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}" "${error}"
					exit 1
				fi
			else
				axel -n 16 -a ${down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}" "${error}"
					exit 1
				fi
			fi
		elif [[ -f ${full_path_file} && ! -f ${full_path_file}.st ]];then
			diy_echo "已经存在文件${path_file}/${down_file_name}" "${info}"
		fi
	else
		diy_echo "请检查下载链接是否正确" "${red}" "${error}"
		exit
	fi
}

auto_ssh_keygen(){
	#host_ip主机地址，ssh_port ssh端口,passwd 密码 user用户
	if [[ -z ${user} || ${user} = 'root' ]];then
		user=root
		key_dir=/root
	else
		key_dir=/home/${user}
	fi
	if [[ -z ${host_ip} ]];then
		input_option "请输入ssh互信主机的主机名(多个空格隔开)" "localhost" "host_ip"
		host_ip=(${input_value[@]})
	fi
	expect_dir=`which expect 2>/dev/null`
	[ -z ${expect_dir} ] && yum install expect -y
	
	su ${user} -c "if [[ ! -f ~/.ssh/id_rsa ]];then ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa -q;fi"

	local i
	i=0
	for host in ${host_ip[@]}
	do
		if [[ -z ${ssh_port[$i]} ]];then
			input_option "请输入root的SSH端口号" "22" "ssh_port"
			ssh_port[$i]=${input_value}
		fi
		if [[ -z ${passwd[$i]} ]];then
			input_option "请输入${host}的${user}用户的密码" "passwd" "passwd"
			passwd[$i]=${input_value}
		fi
		timeout 5 su ${user} -c "ssh ${user}@${host} -p ${ssh_port[$i]} 'echo'" >/dev/null 2>&1
		if [[ $? = 0 ]];then
			diy_echo "主机${host}已经可以免密登录无需配置" "${green}" "${info}"
		else
			su ${user} -c "expect <<-EOF
			set timeout -1
			spawn ssh-copy-id -i ${key_dir}/.ssh/id_rsa.pub ${user}@${host} -p ${ssh_port[$i]}
			expect {
				\"*yes/no\" { send \"yes\\r\";exp_continue}
				\"*password:\" { send \"${passwd[$i]}\\r\";exp_continue}
			}
			EOF"
			su ${user} -c "ssh ${user}@${host} -p ${ssh_port[$i]} 'echo'"
			if [[ $? = 0 ]];then
				diy_echo "主机${host}免密登录配置完成" "${green}" "${info}"
			else
				diy_echo "主机${host}免密登录配置失败" "${red}" "${info}" 
			fi
		fi

		((i++))
	done
}


add_sysuser(){
	info_log "正在添加系统用户"
	while true
	do
		input_option "请输入用户名" "user" "name"
		name=${input_value}
		if `id ${name} > /dev/null 2>&1` ;then
			warning_log "用户已经存在"
			continue
		fi
		if `useradd ${name}` ;then
			success_log "添加用户"
		else
			error_log "添加用户失败请检查权限"
			exit 1
		fi
		break
	done
	#create password
	while true
	do
		input_option "为用户${name}创建一个密码" "123456" "pass1"
		pass1=${input_value}
		input_option "重复输入密码" "123456" "pass2"
		pass2=${input_value}
		if [[ "$pass1" != "$pass2" ]];then
			warning_log "两次密码不一致请重新设置"
			continue
		fi
		echo "$pass2" | passwd --stdin $name
		if [ $? = '0' ];then
			success_log "密码设置完成"
		else
			error_log "密码设置失败"
			exit 1
		fi
		break
	done

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
		weekly
		rotate 26
		compress
		missingok
		notifempty
		copytruncate
		dateext
		}
		EOF
		success_log "成功创建${log_cut_config_file}日志切割配置文件,请复制到/etc/logrotate.d/下"
	else
		error_log "函数add_log_cut缺少参数\$1(日志切割配置模板路径)"
		exit 1
	fi

}

#创建守护进程配置
add_daemon_file(){
	#$1生成守护进程配置文件路径(当前主机路径)
	#还需声明ExecStart变量
	system_service_config_file=$1
	#守护程序类型可选sysvinit、systemd
	daemon_type=${daemon_type:-}

	if [[ -n ${system_service_config_file} ]];then
		pdir=`dirname ${system_service_config_file}`
		if [[ ! -d ${pdir} ]];then
			mkdir -p ${pdir}
		fi
	else
		error_log "函数add_daemon_file缺少参数\$1(生成守护进程配置文件路径)"
		exit 1
	fi

	if [[ -z ${ExecStart} ]];then
		error_log "函数add_daemon_file函数缺少ExecStart变量"
		exit 1
	fi

	if [[ -n ${daemon_type} ]];then
		if [[ "${daemon_type}" = 'sysvinit' ]]; then
			add_daemon_sysvinit_file ${system_service_config_file}
		elif [[ "${daemon_type}" = 'systemd' ]]; then
			add_daemon_systemd_file ${system_service_config_file}
		fi
	else
		if [[ "${os_release}" < '7' ]];then
			add_daemon_sysvinit_file ${system_service_config_file}
		elif [[ "${os_release}" > '6' ]];then
			add_daemon_systemd_file ${system_service_config_file}
		fi
	fi


}

add_daemon_sysvinit_file(){
	#守护进程配置文件路径
	system_service_config_file=$1
	cat >${system_service_config_file}<<-EOF
	#!/bin/bash
	# chkconfig: 345 70 60
	# description: ${soft_name} daemon
	# processname: ${soft_name}

	EnvironmentFile="${EnvironmentFile:-}"
	Environment="${Environment:-}"
	WorkingDirectory="${WorkingDirectory:-}"
	Name="${Name:-${soft_name}}"
	PidFile="${PidFile:-}"
	User="${User:-root}"
	ExecStart="${ExecStart:-}"
	StartArgs="${StartArgs:-}"
	ExecStop="${ExecStop:-}"
	StopArgs="${StopArgs:-}"
	EOF
	cat >>${system_service_config_file}<<-'EOF'
	#EUV
	[[ -f ${EnvironmentFile} ]] && . ${EnvironmentFile}
	[[ -f ${Environment} ]] && export ${Environment}
	[[ -d ${WorkingDirectory} ]] && cd ${WorkingDirectory}
	_pid(){
	  [[ -s $PidFile ]] && pid=$(cat $PidFile) && kill -0 $pid 2>/dev/null || pid=''
	  if [[ -z $PidFile ]];then
	    pid=$(ps aux | grep ${ExecStart} | grep -v grep | awk '{print $2}')
	    if [[ -z $pid ]];then
	      dirname=$(echo ${ExecStart} | awk '{print$1}' | xargs dirname)
	      pid=$(ps aux | grep ${dirname} | grep -v grep | awk '{print $2}')
	    fi
	}

	_start(){
	  _pid
	  if [ -n "$pid" ];then
	    echo -e "\e[00;32m${Name} is running with pid: $pid\e[00m"
	  else
	    echo -e "\e[00;32mStarting ${Name}\e[00m"
	    id -u ${User} >/dev/null
	    if [ $? = 0 ];then
	      su ${User} -c "${ExecStart} ${StartArgs} >/dev/null 2>&1 &"
	    fi
	    _status
	  fi
	}

	_stop(){
	  _pid
	  if [ -n "$pid" ]; then
	    [[ -n "${ExecStop}" ]] && ${ExecStop} ${StopArgs}
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
	success_log "成功创建${system_service_config_file}系统服务配置文件,请复制到/etc/init.d下"
	#删除空值
	[[ -z ${Requires} ]] && sed -i /Requires=/d ${system_service_config_file}
	[[ -z ${WorkingDirectory} ]] && sed -i /WorkingDirectory=/d ${system_service_config_file}
	[[ -z ${Environment} ]] && sed -i /Environment=/d ${system_service_config_file}
	[[ -z ${EnvironmentFile} ]] && sed -i /EnvironmentFile=/d ${system_service_config_file}
	[[ -z ${PIDFile} ]] && sed -i /PIDFile=/d ${system_service_config_file}
	[[ -z ${ExecStartPost} ]] && sed -i /ExecStartPost=/d ${system_service_config_file}
	[[ -z ${SuccessExitStatus} ]] && sed -i /SuccessExitStatus=/d ${system_service_config_file}
}

add_daemon_systemd_file(){
	#守护进程配置文件路径
	system_service_config_file=$1
	cat >${system_service_config_file}<<-EOF
	[Unit]
	Description=${soft_name}
	After=syslog.target network.target
	Requires=${Requires:-}
	
	[Service]
	Type=${Type:-simple}
	User=${User:-root}

	EnvironmentFile=${EnvironmentFile:-}
	Environment=${Environment:-}

	WorkingDirectory=${WorkingDirectory:-}
	PIDFile=${PIDFile:-}
	ExecStart=${ExecStart:-} ${StartArgs:-}
	ExecStartPost=${ExecStartPost:-}
	ExecReload=${ExecReload:-/bin/kill -s HUP \$MAINPID}
	ExecStop=${ExecStop:-/bin/kill -s QUIT \$MAINPID} ${StopArgs}
	SuccessExitStatus=${SuccessExitStatus:-}
	TimeoutStopSec=5
	Restart=${Restart:-on-failure}
	LimitNOFILE=65536
	[Install]
	WantedBy=multi-user.target
	EOF
	success_log "成功创建${system_service_config_file}系统服务配置文件,请复制到/etc/systemd/system下"
	[[ -z ${Requires} ]] && sed -i /Requires=/d ${system_service_config_file}
	[[ -z ${WorkingDirectory} ]] && sed -i /WorkingDirectory=/d ${system_service_config_file}
	[[ -z ${Environment} ]] && sed -i /Environment=/d ${system_service_config_file}
	[[ -z ${EnvironmentFile} ]] && sed -i /EnvironmentFile=/d ${system_service_config_file}
	[[ -z ${PIDFile} ]] && sed -i /PIDFile=/d ${system_service_config_file}
	[[ -z ${ExecStartPost} ]] && sed -i /ExecStartPost=/d ${system_service_config_file}
	[[ -z ${SuccessExitStatus} ]] && sed -i /SuccessExitStatus=/d ${system_service_config_file}
}
#添加守护进程
add_system_service(){
	#$1服务名 $2服务文件路径
	service_name=$1
	service_file_dir=$2

	if [[ "${os_release}" < '7' ]]; then
		\cp ${service_file_dir} /etc/init.d/${service_name}
		chmod +x /etc/init.d/${service_name}
		diy_echo "service ${service_name} start|stop|restart|status" "$yellow"
	elif [[ "${os_release}" > '6' ]]; then
		\cp ${service_file_dir} /etc/systemd/system/${service_name}.service
		diy_echo "systemctl start|stop|restart|status ${service_name}" "$yellow"
	fi

}

service_control(){
	#$1守护进程名称
	#$2操作指令
	service_name=$1
	arg=$2
	if [[ "x${service_name}" = "x" || "x${arg}" = "x" ]];then
		error_log "函数service_control缺少参数"
	fi

	if [[ ${os_release} < '7' ]];then
		service ${service_name} ${arg}
		if [[ $? = '0' ]];then
			success_log "service ${service_name} ${arg} 操作完成"
		else
			error_log "service ${service_name} ${arg} 操作失败"
		fi
	fi

	if [[  ${os_release} > '6' ]];then
		systemctl daemon-reload
		systemctl ${arg} ${service_name}
		if [[ $? = '0' ]];then
			success_log "service ${service_name} ${arg} 操作完成"
		else
			error_log "service ${service_name} ${arg} 操作失败"
		fi
	fi

}
#添加环境变量
add_sys_env(){
	>/etc/profile.d/${soft_name}.sh
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
