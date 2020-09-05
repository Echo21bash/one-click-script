#!/bin/bash

down_file(){
	github_mirror=(https://github.wuyanzheshui.workers.dev https://hub.fastgit.org https://download.fastgit.org https://github.com.cnpmjs.org)
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
					mirror_down_url="${mirror}/${down_url#*github.com/}"
					break
				fi
			done
		fi
		#获取下载完成路径及文件名
		if [[ -d ${path_file} ]];then
			full_path_file=${path_file}/${down_filename}
		else
			full_path_file=${path_file}
		fi
		#开始下载	
		if [[ ! -f ${full_path_file} && ! -f ${full_path_file}.st ]];then
			diy_echo "正在下载${down_url}" "${info}"
			if [[ -n ${mirror_down_url} ]];then
				axel -n 16 -a ${mirror_down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}"
					exit 1
				fi
			else
				axel -n 16 -a ${down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}"
					exit 1
				fi
			fi
		elif [[ -f ${full_path_file} && -f ${full_path_file}.st ]];then
			diy_echo "正在断点续传下载${down_url}" "${info}"
			if [[ -n ${mirror_down_url} ]];then
				axel -n 16 -a ${mirror_down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}"
					exit 1
				fi
			else
				axel -n 16 -a ${down_url} -o ${path_file}
				if [[ $? -ne '0' ]];then
					diy_echo "下载失败" "${red}"
					exit 1
				fi
			fi
		elif [[ -f ${full_path_file} && ! -f ${full_path_file}.st ]];then
			diy_echo "已经存在文件${path_file}/${down_filename}" "${info}"
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

add_sysuser_sudo(){
  #add visudo
  echo -e "${info} Add user to sudoers file"
  [ ! -f /etc/sudoers.back ] && \cp /etc/sudoers /etc/sudoers.back
  SUDO=`grep -w "$name" /etc/sudoers |wc -l`
  if [ $SUDO -eq 0 ];then
      sed -i '/^root/i '${name}'  ALL=(ALL)       NOPASSWD: ALL' /etc/sudoers
      sleep 1
  fi
  [ ! -z `grep -ow "$name" /etc/sudoers` ] && action "创建用户$name并将其加入visudo"  /bin/true
}

add_sysuser_sftp(){
	#set sftp homedir
	echo -e "${info} Please enter sftp home directory"
	read -p "(default:/data/${name}/sftp)" sftp_dir
	if [[ ${sftp_dir} = '' ]];then
		sftp_dir="/data/${name}/sftp"
	fi
	if [[ ! -d ${sftp_dir} ]];then
		mkdir -p ${sftp_dir}
	fi
	#父目录
	dname=$(dirname ${sftp_dir})
	groupadd sftp_users>/dev/null 2>&1
	usermod -G sftp_users -d ${dname} -s /sbin/nologin ${name}>/dev/null 2>&1
	chown -R ${name}.sftp_users ${sftp_dir}
	sed -i 's[^Subsystem.*sftp.*/usr/libexec/openssh/sftp-server[#Subsystem	sftp	/usr/libexec/openssh/sftp-server[' /etc/ssh/sshd_config
	if [[ -z `grep -E '^ForceCommand    internal-sftp' /etc/ssh/sshd_config` ]];then
		cat >>/etc/ssh/sshd_config<<-EOF
		Subsystem       sftp    internal-sftp
		Match Group sftp_users
		ChrootDirectory %h
		ForceCommand    internal-sftp
		EOF
	fi
}

update_kernel(){
	diy_echo 'Updating kernel is risky. Please backup information.' "${red}"
	echo -e "${info} The current kernel version is ${kel}"
	echo -e "${info} press any key to continue"
	read
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
		echo -e "${error} Install elrepo failed, please check it."
		exit 1
	fi
	if [[ ${kernel_type} = '1' ]];then
		yum --enablerepo=elrepo-kernel install  -y kernel-lt kernel-lt-devel
	else
		yum --enablerepo=elrepo-kernel install  -y kernel-ml kernel-ml-devel
	fi
	if [[ $? != '0' ]];then
		echo -e "${error} Failed to install kernel, please check it"
		exit 1
	fi
	if (( ${os_release} < '7' ));then
		if [ ! -f "/boot/grub/grub.conf" ]; then
			echo -e "${error} /boot/grub/grub.conf not found, please check it."
			exit 1
		fi
		sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
	elif (( ${os_release} >= '7' ));then
		if [ ! -f "/boot/grub2/grub.cfg" ]; then
			echo -e "${error} /boot/grub2/grub.cfg not found, please check it."
			exit 1
		fi
		grub2-set-default 0
	fi
	echo -e "${info} The system needs to reboot."
    read -p "Do you want to restart system? [y/n]" is_reboot
    if [[ ${is_reboot} = "y" || ${is_reboot} = "Y" ]]; then
        reboot
    else
        echo -e "${info} Reboot has been canceled..."
        exit 0
    fi
}

clear_install(){
	if [[ -n ${install_dir} ]];then
		rm -rf ${tar_dir}
	fi
}
