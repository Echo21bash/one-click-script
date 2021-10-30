#!/bin/bash

#多功能备份脚本
#2019.2

#本地备份存放目录
backup_home_dir=/data/backup
#备份日志
log_dir=/data/backup/bak.log
#工程名
project_name='my-web'
#备份保留时长(天)
backup_save_time='90'

enable_ftp='0'
ftp_host='127.0.0.1'
ftp_port='21'
ftp_username='admin'
ftp_password='admin'
ftp_dir='/backup'

enable_backup_dir=0
#需要备份的目录
backup_dir=(/data/ftp /data/file)

enable_backup_db=0
#数据库用户密码ip端口必须一一对应
mysql_user=()
mysql_passwd=()
mysql_ip=()
mysql_port=()
#每个mysql主机需要备份库的个数
mysql_db_num=()
#需要备份的数据库按顺序添加
db_name=()

enable_backup_svn=0
#需要备份的目录
svn_project_dir=
#备份方案
#全量备份
svn_full_back='0'
#增量备份
svn_incremental_back='0'
svn_back_cycle='7'
#固定版本步长备份
svn_fixed_ver_back='0'
svn_back_size='1000'

backup_sql(){

today_back_name="${project_name}-db-${db_name[$k]}-$(date +%Y%m%d)"
old_back_name="${project_name}-db-${db_name[$k]}-$(date -d "${backup_save_time} days ago" +%Y%m%d)"

${mysqldump} -u${mysql_user[$i]} -p${mysql_passwd[$i]} -h${mysql_ip[$i]} -P${mysql_port[$i]} ${db_name[$k]} --log-error=${log_dir} > ${today_back_name}.sql
if [ $? = "0" ];then
	tar zcf ${today_back_name}.sql.tar.gz -C ${backup_home_dir} ${today_back_name}.sql && rm -rf ${today_back_name}.sql
	echo -e "打包${today_back_name}文件成功">>${log_dir}
	rm -rf ${old_back_name}.sql.tar.gz && echo "删除本地${old_back_name}.sql.tar.gz完成">>${log_dir}
	[ ${enable_ftp} = 0 ] && ftp_control ${today_back_name}.sql.tar.gz ${old_back_name}.sql.tar.gz
fi

}

backup_dir(){

if [[ -d $1 ]];then
	backup_path=$1
	dir_name=`echo ${backup_path##*/}`
	pre_dir=`echo ${backup_path}|sed 's/'${dir_name}'//g'`
	today_dir_gz="${project_name}-dir-${dir_name}-$(date +"%Y%m%d")"
	old_dir_gz="${project_name}-dir-${dir_name}-$(date -d "${backup_save_time} days ago" +%Y%m%d)"
    
	tar zcf ${today_dir_gz}.tar.gz -C ${pre_dir} ${dir_name}.tar.gz>>${log_dir} 2>&1
	if [ $? = "0" ];then	
		echo "打包${today_dir_gz}.tar.gz文件成功">>${log_dir}
		rm -rf ${old_dir_gz}.tar.gz && echo "删除本地${old_dir_gz}.tar.gz完成">>${log_dir}
		[ ${enable_ftp} = 0 ] && ftp_control ${today_dir_gz}.tar.gz ${old_dir_gz}.tar.gz
	fi
else
	echo "不存在$1文件夹">>${log_dir}
fi

}

backup_svn(){

today_back_name="${project_name}-svn-$(date +%Y%m%d)"
old_back_name="${project_name}-svn-$(date -d "${backup_save_time} days ago" +%Y%m%d)"

_full_back(){

svnadmin dump ${svn_project_dir} >${backup_home_dir}/${today_back_name}.full.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.full.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.full.dump
	rm -rf ${today_back_name}.full.dump ${old_back_name}.full.dump.tar.gz
fi
}

_incremental_back(){

svnadmin dump ${svn_project_dir} -r ${svn_last_ver}:HEAD --incremental >${backup_home_dir}/${today_back_name}.${svn_last_ver}-HEAD.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.${svn_last_ver}-HEAD.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.${svn_last_ver}-HEAD.dump
	rm -rf ${today_back_name}.*HEAD.dump ${old_back_name}.*HEAD.dump.tar.gz
fi
}

_fixed_ver_back(){

svnadmin dump ${svn_project_dir} -r ${svn_old_ver}:${svn_last_ver} >${backup_home_dir}/${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
	rm -rf ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
	ls ${backup_home_dir} | grep -oE "${old_back_name}.[0-9]{1,}-[0-9]{1,}.dump.tar.gz" | xargs rm -rf
fi
}

#全量备份
if [[ ${svn_full_back} = 1 && ${svn_incremental_back} = 0 ]];then
	_full_back
fi
#全量备份加增量
if [[ ${svn_full_back} = 1 && ${svn_incremental_back} = 1 ]];then
	if [[ -f ${backup_home_dir}/${project_name}-svn-$(date -d "${svn_back_cycle} days ago" +%Y%m%d).full.dump.tar.gz ]];then
		svn_last_ver=$(svnlook youngest ${svn_project_dir}) && echo ${svn_last_ver}>/tmp/svn_last_ver.txt
		_full_back
	elif [[ ! -f /tmp/svn_last_ver.txt ]];then
		svn_last_ver=$(svnlook youngest ${svn_project_dir}) && echo ${svn_last_ver}>/tmp/svn_last_ver.txt
		_full_back
	else
		svn_last_ver=$(cat /tmp/svn_last_ver.txt)
		_incremental_back
	fi
fi
#固定版本步长
if [[ ${svn_fixed_ver_back} = 1 ]];then
	svn_last_ver=$(svnlook youngest ${svn_project_dir})
	svn_old_ver=$(((${svn_last_ver}-${svn_back_size})))
	[[ ${svn_old_ver} < 0 ]] && svn_old_ver=0
	_fixed_ver_back
fi
}

backup_sql_control(){
#外循环次数控制
num=$(expr ${#mysql_user[@]} - 1)
mysqldump --help>/dev/null 2>&1
if [ $? = 0 ];then
	mysqldump='mysqldump'
else
	mysqldump=$(find / -name mysqldump | grep -ei .*/mysql.*/bin/mysqldump)
fi

k=0
q=0
for((i=0;i<=${num};i++))
do		
	for((j=1;j<=${mysql_db_num[$q]};j++))
	do
	backup_sql
	#内循环内按顺取${db_name}数据库
	k=`expr $k + 1`
	done
	#外循环内按顺取${mysql_db_num}控制内循环的次数
	q=`expr $q + 1`
done
}

backup_dir_control(){

for dd in ${backup_dir[@]}
do
	backup_dir ${dd}
done
}

ftp_control(){

echo "正在上传文件$1">>${log_dir}
cd ${backup_home_dir}
lftp ${ftp_host} -u ${ftp_username},${ftp_password} <<-EOF
cd ${ftp_dir}
put ${1}
bye
EOF
if [ $? = '0' ];then
	echo "文件$1上传完成">>${log_dir}
	lftp ${ftp_host} -u ${ftp_username},${ftp_password} <<-EOF
	cd ${ftp_dir}
	rm ${2}
	bye
	EOF
	if [ $? = 0 ];then
		echo "成功删除ftp文件$2">>${log_dir}
	fi
else
	echo "文件$1上传失败">>${log_dir}
fi
}

[ ! -d ${backup_home_dir} ] && mkdir -p ${backup_home_dir}
cd ${backup_home_dir}
echo "开始时间:$(date +%y-%m-%d-%H:%M:%S)">>${log_dir}

[[ ${enable_backup_db} = 1 ]] && backup_sql_control
[[ ${enable_backup_dir} = 1 ]] && backup_dir_control
[[ ${enable_backup_svn} = 1 ]] && backup_svn >>${log_dir} 2>&1

echo -e "结束时间:$(date +%y-%m-%d-%H:%M:%S)\n">>${log_dir}