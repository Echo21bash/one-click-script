#!/bin/bash

multi_function_backup_script_set(){
	output_option "请选择需要备份的类型" "mysql dir svn" "back_type"
	back_type=(${output_value[@]})
	input_option "备份保留时长(天)" "90" "backup_save_time"
	input_option "备份文件存储路径" "/data/backup" "backup_home_dir"
	backup_home_dir=${input_value}
	backup_config
	if [[ ${back_type[@]} =~ 'mysql' ]];then
		mysql_backup_set
	fi
	if [[ ${back_type[@]} =~ 'dir' ]];then
		dir_backup_set
	fi
	if [[ ${back_type[@]} =~ 'svn' ]];then
		svn_backup_set
	fi
}

mysql_backup_set(){
	diy_echo "此备份脚本可以备份多个MySQL主机分别备份不同的库" "" "${info}"
	input_option "请输入要备份MySQL主机的个数" "1" "mysql_num"
	if [[ ${mysql_num} > 1 ]];then
		input_option '请依次输入mysql连接ip' '192.168.1.2 192.168.1.3' 'mysql_ip'
		mysql_ip=(${input_value[@]})
		input_option '请依次输入mysql连接端口' '3306 3307' 'mysql_port'
		input_option '请依次输入mysql连接用户名' 'root user' 'mysql_user'
		mysql_user=(${input_value[@]})
		input_option '请依次输入mysql连接密码' '123456 654321' 'mysql_passwd'
		mysql_passwd=(${input_value[@]})
		input_option '请依次输入所有要备份的库名' 'mysql test' 'db_name'
		db_name=(${input_value[@]})
		input_option '请依次输入每个主机备份库的个数' '1 1' 'mysql_db_num'
		mysql_db_num=(${input_value[@]})
	else
		input_option "请输入mysql连接ip" "192.168.1.2" "mysql_ip"
		mysql_ip=${input_value}
		input_option "请输入mysql连接端口" "3306" "mysql_port"
		input_option "请输入mysql连接用户名" "root" "mysql_user"
		mysql_user=${input_value}
		input_option "请输入mysql连接密码" "123456" "mysql_passwd"
		mysql_passwd=${input_value}
		input_option "请输入所有要备份的库名" "mysql" "db_name"
		db_name=(${input_value[@]})
		mysql_db_num=${#db_name[@]}
	fi
	sed -i "s#enable_backup_db=0#enable_backup_db=1#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#mysql_user=()#mysql_user=(${mysql_user[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#mysql_passwd=()#mysql_passwd=(${mysql_passwd[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#mysql_ip=()#mysql_ip=(${mysql_ip[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#mysql_port=()#mysql_port=(${mysql_port[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#mysql_db_num=()#mysql_db_num=(${mysql_db_num[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#db_name=()#db_name=(${db_name[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
}

dir_backup_set(){
	diy_echo "此备份脚本可以备份多个目录" "" "${info}"
	input_option "请输入要备份的目录" "/data/ftp /data/file" "backup_dir"
	backup_dir=(${input_value[@]})
	sed -i "s#enable_backup_dir=0#enable_backup_dir=1#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#backup_dir=()#backup_dir=(${backup_dir[@]})#" ${workdir}/script/other/multi_function_backup_script.sh
}

svn_backup_set(){
	input_option "请输入要备份的目录" "/data/svn" "svn_project_dir"
	svn_project_dir=${input_value}
	output_option "请选择备份方案" "全量备份 全量备份+增量备份 固定版本步长备份" "svn_back_type"
	sed -i "s#enable_backup_svn=0#enable_backup_svn=1#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#svn_project_dir=.*#svn_project_dir="${svn_project_dir}"#" ${workdir}/script/other/multi_function_backup_script.sh	

	if [[ ${svn_back_type} = 1 ]];then
		sed -i "s#svn_full_back='0'#svn_full_back='1'#" ${workdir}/script/other/multi_function_backup_script.sh
	elif [[ ${svn_back_type} = 2 ]];then
		input_option "请输入要全量备份周期(天)" "7" "svn_back_cycle"
		sed -i "s#svn_full_back='0'#svn_full_back='1'#" ${workdir}/script/other/multi_function_backup_script.sh
		sed -i "s#svn_incremental_back='0'#svn_incremental_back='1'#" ${workdir}/script/other/multi_function_backup_script.sh
		sed -i "s#svn_back_cycle='7'#svn_back_cycle="${svn_back_cycle}"#" ${workdir}/script/other/multi_function_backup_script.sh
	elif [[ ${svn_back_type} = 3 ]];then
		input_option "请输入要备份版本号步长值" "500" "svn_back_size"
		sed -i "s#svn_fixed_ver_back='0'#svn_fixed_ver_back='1'#" ${workdir}/script/other/multi_function_backup_script.sh
		sed -i "s#svn_back_size='1000'#svn_back_size="${svn_back_size}"#" ${workdir}/script/other/multi_function_backup_script.sh
	fi

}

backup_config(){

	sed -i "s#^backup_home_dir=/data/backup#backup_home_dir=${backup_home_dir}#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#^log_dir=.*#log_dir=${backup_home_dir}/bakup.log#" ${workdir}/script/other/multi_function_backup_script.sh
	sed -i "s#^backup_save_time='90'#backup_save_time=${backup_save_time}#" ${workdir}/script/other/multi_function_backup_script.sh
}
