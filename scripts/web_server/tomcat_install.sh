#!/bin/bash

tomcat_env_load(){
	tmp_dir=/usr/local/src/tomcat_tmp
	soft_name=tomcat
	program_version=('7' '8')
	url="http://mirrors.ustc.edu.cn/apache/tomcat"
	select_version
	install_dir_set
	online_version
}

tomcat_down(){
	down_url="${url}/tomcat-${version_number}/v${detail_version_number}/bin/apache-tomcat-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/apache-tomcat-${detail_version_number}.tar.gz ${tmp_dir}
}

tomcat_set(){
	input_option "请输入部署个数" "1" "tomcat_num"
	[[ ${tomcat_num} > 1 ]] && diy_echo "部署多个tomcat服务一定要避免端口冲突" "${yellow}" "${warning}"
}

tomcat_other_set(){
		input_option "设置Tomcat文件夹名称,注意不要和现有的冲突" "tomcat" "home_dir_name"
		home_dir_name=${input_value}
		input_option "请输入service服务名称" "tomcat" "service_name"
		service_name=${input_value}
		input_option "请输入http端口号" "8080" "http_port"

}

tomcat_install(){

	for ((i=1;i<=tomcat_num;i++));
	do
		echo -e "${info} 开始设置第${i}个Tomcat."
		tomcat_other_set
		home_dir=${install_dir}/${home_dir_name}
		[ ! -d ${home_dir} ] && mkdir -p ${home_dir}
		\cp -rp ${tar_dir}/* ${install_dir}/${home_dir_name}
		tomcat_config
		tomcat_manager_config
		memory_overflow_config
		add_tomcat_service
		echo -e "${info} 好的设置好${i}个Tomcat了."
	done

}

tomcat_config(){
	#修改配置参数
	sed -i '/<Connector port="8080" protocol="HTTP\/1.1"/,/redirectPort="8443" \/>/s/redirectPort="8443" \/>/redirectPort="8443"/' ${home_dir}/conf/server.xml
	sed -i '/^               redirectPort="8443"$/r '${workdir}'/config/tomcat_service.txt' ${home_dir}/conf/server.xml
	sed -i '/<\/Host>/i \      <!--<Context path="" docBase="" reloadable="true">\n      <\/Context>-->' ${home_dir}/conf/server.xml

	#禁用shutdown端口
	sed -i 's/<Server port="8005"/<Server port="-1"/' ${home_dir}/conf/server.xml
	#注释AJP
	sed -i 's#<Connector port="8009".*#<!-- <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" /> -->#' ${home_dir}/conf/server.xml
	#修改http端口
	sed -i 's/<Connector port="8080"/<Connector port="'${http_port}'"/' ${home_dir}/conf/server.xml
	#日志切割
	add_log_cut ${home_dir_name} ${home_dir}/logs/catalina.out
}

tomcat_manager_config(){
	N=`cat -n ${home_dir}/conf/tomcat-users.xml | grep '</tomcat-users>' | awk '{print $1}'`
	sed -i ''$N'i<role rolename="manager-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<role rolename="admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<user username="admin" password="admin" roles="manager-gui,admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
}

check_java_version(){

	java_version=$(java -version 2>&1 | grep -Eo [0-9.]+_[0-9]+ | awk 'NR==1{print}' | grep -Eo '[0-9]{1}\.[0-9]{1}')
	if [[ -z ${java_version} ]];then
		diy_echo "检测到java环境未安装" "${yellow}" "${error}"
		java_install_ctl
	fi

}

memory_overflow_config(){

	N=`grep -n '^# OS' ${home_dir}/bin/catalina.sh | awk -F ':' '{print $1}'`
	sed -i "$N i# JAVA_OPTS (Optional) Java runtime options used when any command is executed.\n" ${home_dir}/bin/catalina.sh
	
	if [[ ${java_version} < '1.8' ]];then
		sed -i "/^# JAVA_OPTS.*/r ${workdir}/config/tomcat_jvm7.txt" ${home_dir}/bin/catalina.sh
	else
		sed -i "/^# JAVA_OPTS.*/r ${workdir}/config/tomcat_jvm8.txt" ${home_dir}/bin/catalina.sh
	fi
}

add_tomcat_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/startup.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service ${home_dir}/init
	add_system_service ${service_name} ${home_dir}/init
}

tomcat_install_ctl(){
	tomcat_env_load
	tomcat_set
	tomcat_down
	tomcat_install
	
}