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
	info="[${green}info${plain}]"
	warning="[${yellow}warning${plain}]"
	error="[${red}error${plain}]"
}

diy_echo(){
	#$1内容 $2颜色(非必须) $3前缀关键字(非必须)
	if [[ $# = '3' ]];then
		echo -e "$3 $2$1${plain}"
	fi
	
	if [[ $# = '2' ]];then
		if [[ $2 =~ 'info' || $2 =~ 'warning' || $2 =~ 'error' ]];then
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
	#只允许
	only_allow_numbers ${output[@]}
	if [[ $? != '0' ]];then
		diy_echo "输入错误请重新选择" "${red}" "${error}"
		exit 1
	fi
	#清空output_value
	output_value=()
	local k
	k=0
	for item in ${output[@]}
	do	
		#选项数组
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
	local j=0
	for ((j=0;j<$#;j++))
	do
		tmp=($@)
		if [ -z "$(echo ${tmp[$j]} | sed 's#[0-9]##g')" ];then
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
#内核版本
	kel=`uname -r | grep -oE [0-9]{1}.[0-9]{1,\}.[0-9]{1,\}-[0-9]{1,\}`
	ping -c 1 www.baidu.com >/dev/null 2>&1
	if [ $? = '0' ];then
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
	net_name=$(ip addr | grep -oE 'eth[0-9a-z]{1,3}|eno[0-9a-z]{1,3}|ens[0-9a-z]{1,3}|enp[0-9a-z]{1,3}' | head -n 1)
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
#必须函数调用
colour_keyword