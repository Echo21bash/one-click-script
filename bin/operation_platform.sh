#!/bin/bash

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${output_value[@]} =~ 'elasticsearch' ]];then
		elasticsearch_install_ctl
	elif [[ ${output_value[@]} =~ 'logstash' ]];then
		logstash_install_ctl
	elif [[ ${output_value[@]} =~ 'kibana' ]];then
		kibana_install_ctl
	elif [[ ${output_value[@]} =~ 'filebeat' ]];then
		filebeat_install_ctl
	fi	
}

elasticsearch_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	else
		input_option "请输入部署总个数($(diy_echo 必须是奇数 $red))" "3" "deploy_num_total"
		input_option '请输入所有部署elsearch的机器的ip地址,第一个为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'elsearch_ip'
		elsearch_ip=(${input_value[@]})
		input_option '请输入每台机器部署elsearch的个数,第一个为本机部署个数(多个使用空格分隔)' '2 1' 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}
		diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	fi
}

elasticsearch_install(){

	useradd -M elsearch
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir}/* ${home_dir}
		chown -R elsearch.elsearch ${home_dir}
		elasticsearch_conf
		add_elasticsearch_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		elasticsearch_server_list
		chown -R elsearch.elsearch ${tar_dir}
		for ((i=1;i<=${deploy_num_local};i++))
		do
			\cp -rp ${tar_dir} ${install_dir}/elsearch-node${i}
			home_dir=${install_dir}/elsearch-node${i}
			elasticsearch_conf
			add_elasticsearch_service
			elsearch_port=$((${elsearch_port}+1))
			elsearch_tcp_port=$((${elsearch_tcp_port}+1))
		done
	fi

}

elasticsearch_server_list(){

	local i
	local j
	local g
	j=0
	g=0

	for ip in ${elsearch_ip[@]}
	do
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				discovery_hosts[$g]="\"${elsearch_ip[$j]}:$(((elsearch_tcp_port+$i)))\","
				g=$(((${g}+1)))
			done	
		done
		j=$(((${j}+1)))
	done
	#将最后一个值得逗号去掉
	discovery_hosts[$g-1]=$(echo ${discovery_hosts[$g-1]} | grep -Eo "[\"\.0-9:]{1,}")
	discovery_hosts=$(echo ${discovery_hosts[@]})
}

elasticsearch_conf(){
	get_ip
	if [[ ${deploy_mode} = '1' ]];then
		conf_dir=${home_dir}/config
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
	else
		conf_dir=${home_dir}/config

		sed -i "s/#cluster.name.*/cluster.name: my-elsearch-cluster/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#node.name.*/node.name: ${local_ip}_node${i}\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#discovery.zen.ping.unicast.hosts.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]\ndiscovery.zen.ping_timeout: 30s/" ${conf_dir}/elasticsearch.yml
		sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
	fi

}

add_elasticsearch_service(){
	Type=forking
	User=elsearch
	ExecStart="${home_dir}/bin/elasticsearch"
	ARGS="-d"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service elsearch ${home_dir}/init
	else
		add_system_service elsearch-node${i} ${home_dir}/init
	fi
}

elasticsearch_install_ctl(){
	install_version elasticsearch
	install_selcet
	elasticsearch_install_set
	install_dir_set
	download_unzip
	elasticsearch_install
	clear_install
}

logstash_install_set(){
echo
}

logstash_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/config.d
	logstash_conf
	add_logstash_service
}

logstash_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
	sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
	sed -i "s@# path.config.*@path.config: ${home_dir}/config.d@" ${conf_dir}/logstash.yml
	sed -i "s/# http.host.*/http.host: \"${local_ip}\" " ${conf_dir}/logstash.yml
	sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
	sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
}

add_logstash_service(){
	Type=simple
	ExecStart="${home_dir}/bin/logstash"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service logstash ${home_dir}/init
}

logstash_install_ctl(){
	install_version logstash
	install_selcet
	logstash_install_set
	install_dir_set
	download_unzip
	logstash_install
	clear_install
}

kibana_install_set(){
	input_option "输入http端口号" "5601" "kibana_port"
	input_option "输入elasticsearch服务http地址" "127.0.0.1:9200" "elasticsearch_ip"
	elasticsearch_ip=${input_value}
}

kibana_install(){
	
	mv ${tar_dir}/* ${home_dir}
	kibana_conf
	add_kibana_service
}

kibana_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/#server.port.*/server.port: ${kibana_port}/" ${conf_dir}/kibana.yml
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s@#elasticsearch.url.*@elasticsearch.url: http://${elasticsearch_ip}@" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	ExecStart="${home_dir}/bin/kibana"
	conf_system_service 
	add_system_service kibana ${home_dir}/kibana_init
}

kibana_install_ctl(){
	install_version kibana
	install_selcet
	kibana_install_set
	install_dir_set
	download_unzip
	kibana_install
	clear_install
}

filebeat_install(){
	mv ${tar_dir}/* ${home_dir}
	filebeat_conf
	add_filebeat_service
}

filebeat_conf(){
	get_ip
	conf_dir=${home_dir}/config
}

add_filebeat_service(){
	ExecStart="${home_dir}/filebeat"
	conf_system_service 
	add_system_service filebeat ${home_dir}/init
}

filebeat_install_ctl(){
	install_version filebeat
	install_selcet
	#filebeat_install_set
	install_dir_set
	download_unzip
	filebeat_install
	clear_install
}

zabbix_set(){
	output_option "请选择要安装的模块" "zabbix-server zabbix-agent zabbix-java zabbix-proxy" "install_module"
	install_module_value=(${output_value[@]})
	module_configure=$(echo ${install_module_value[@]} | sed s/zabbix/--enable/g)
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
		diy_echo "现在设置zabbix-server相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的数据库地址" "127.0.0.1" "zabbix_db_host"
		zabbix_db_host=${input_value}
		input_option "请输入要连接的数据库端口" "3306" "zabbix_db_port"
		input_option "请输入要连接的数据库名" "zabbix" "zabbix_db_name"
		zabbix_db_name=${input_value}
		input_option "请输入要连接的数据库用户" "root" "zabbix_db_user"
		zabbix_db_user=${input_value}
		input_option "请输入要连接的数据库密码" "123456" "zabbix_db_passwd"
		zabbix_db_passwd=${input_value}
	fi
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		diy_echo "现在设置zabbix-agent相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的zabbix-server地址" "127.0.0.1" "zabbix_server_host"
		zabbix_server_host=${input_value}
		input_option "请设置zabbix-agent的主机名地址" "zabbix_server" "zabbix_agent_host_name"
		zabbix_agent_host_name=${input_value}
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		echo
	fi
}

zabbix_install(){

	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	yum -y install net-snmp-devel libxml2-devel libcurl-devel mysql-devel libevent-devel
	cd ${tar_dir}
	./configure --prefix=${home_dir} ${module_configure} --with-mysql --with-net-snmp --with-libcurl --with-libxml2
	make && make install
	if [ $? = '0' ];then
		diy_echo "编译完成..." "" "${info}"
	else
		diy_echo "编译失败!" "" "${error}"
		exit 1
	fi

}

zabbix_config(){

	groupadd zabbix >/dev/null 2>&1
	useradd zabbix -M -g zabbix -s /bin/false >/dev/null 2>&1
	mkdir -p ${home_dir}/logs
	chown -R zabbix.zabbix ${home_dir}/logs
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
	
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_server.log#' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_server.pid@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBHost=.*@DBHost='${zabbix_db_host}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBName=.*@DBName='${zabbix_db_name}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBUser=.*@DBUser='${zabbix_db_user}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPassword=.*@DBPassword='${zabbix_db_passwd}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPort=.*@DBPort='${zabbix_db_port}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_server.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_server.conf.d/*.conf@' ${home_dir}/etc/zabbix_server.conf
	fi
 
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then

		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_agentd.pid@' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_agentd.log#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Server=.*#Server='${zabbix_server_host}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Hostname=.*#Hostname='${zabbix_agent_host_name}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_agentd.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_agentd.conf.d/*.conf@' ${home_dir}/etc/zabbix_agentd.conf
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		sed -i 's@^PID_FILE=.*@PID_FILE='${home_dir}'/logs/zabbix_java.pid@' ${home_dir}/sbin/zabbix_java/settings.sh
		sed -i 's@/tmp/zabbix_java.log@'${home_dir}'/logs/zabbix_java.log@' ${home_dir}/sbin/zabbix_java/lib/logback.xml
	fi

}

add_zabbix_service(){
	Type="forking"
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_server.conf"
		PIDFile="${home_dir}/logs/zabbix_server.pid"
		ExecStart="${home_dir}/sbin/zabbix_server -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-serverd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_agentd.conf"
		PIDFile="${home_dir}/logs/zabbix_agentd.pid"
		ExecStart="${home_dir}/sbin/zabbix_agentd -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-agentd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		PIDFile="${home_dir}/logs/zabbix_java.pid"
		ExecStart="${home_dir}/sbin/zabbix_java/startup.sh"
		conf_system_service
		add_system_service zabbix-java-gateway ${home_dir}/init
	fi
}

zabbix_install_ctl(){
	install_version zabbix
	install_selcet
	zabbix_set
	install_dir_set
	download_unzip
	zabbix_install
	zabbix_config
	add_zabbix_service
	clear_install
}

docker_install(){

	[[ -n `which docker 2>/dev/null` ]] && diy_echo "检测到可能已经安装docker请检查..." "${yellow}" "${warning}" && exit 1
	diy_echo "正在安装docker..." "" "${info}"
	system_optimize_yum
	if [[ ${os_release} < "7" ]];then
		yum install -y docker
	else
		wget -O /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo >/dev/null 2>&1
		yum install -y docker-ce
	fi
	mkdir /etc/docker
	cat >/etc/docker/daemon.json <<-'EOF'
	{
	  "registry-mirrors": [
	    "https://dockerhub.azk8s.cn",
	    "https://docker.mirrors.ustc.edu.cn",
	    "http://hub-mirror.c.163.com"
	  ],
	  "max-concurrent-downloads": 10,
	  "log-driver": "json-file",
	  "log-level": "warn",
	  "log-opts": {
		    "max-size": "10m",
		    "max-file": "3"
		    },
		  "data-root": "/var/lib/docker"
	  }
	EOF
}

k8s_env_check(){

	[[ ${os_release} < "7" ]] && diy_echo "k8s只支持CentOS7" "${red}" "${error}" && exit 1
	[[ -n `which kubectl 2>/dev/null` || -n `which kubeadm 2>/dev/null` || -n `which kubelet 2>/dev/null` ]] && diy_echo "k8s可能已经安装请检查..." "${red}" "${error}" && exit 1
	[[ -z `which docker 2>/dev/null` ]] && diy_echo "检测到未安装docker" "${yellow}" "${warning}" && docker_install
	if [[ ! -f /etc/yum.repos.d/kubernetes.repo ]];then
		cat >/etc/yum.repos.d/kubernetes.repo<<-EOF
		[kubernetes]
		name=Kubernetes
		baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
		enabled=1
		gpgcheck=0
		EOF
	fi
	#开启ipvs
	cat >/etc/modules-load.d/10-k8s-modules.conf<<-EOF
	br_netfilter
	ip_vs
	ip_vs_rr
	ip_vs_wrr
	ip_vs_sh
	nf_conntrack_ipv4
	nf_conntrack
	EOF
	modprobe br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4 nf_conntrack
	cat >/etc/sysctl.d/95-k8s-sysctl.conf<<-EOF
	net.ipv4.ip_forward = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-arptables = 1
	EOF
	sysctl -p /etc/sysctl.d/95-k8s-sysctl.conf >/dev/null
}

k8s_install_set(){

	output_option "选择安装方式" "kubeadm 二进制安装" install_method
	output_option "选择节点类型" "master node" node_type
	node_type=${output_value}
	if [[ ${node_type} = 'master' ]];then
		diy_echo "禁止master节点部署pod时某些组件可能会等待合适的node节点才会部署完成" "${yellow}" "${info}"
		input_option "是否允许master节点部署pod" "y" k8s_master_pod && k8s_master_pod=${ipput_value}
		output_option "选择网络组件" "flannel" k8s_net && k8s_net=${output_value}
		output_option "选择周边组件" "dashboard metrics heapster" k8s_module && k8s_module=${output_value[@]}
	else
		diy_echo "master节点执行kubeadm token list" "" "${info}"
		input_option "请输入master节点token" "22d578.d921a7cf51352441" tonken && tonken=${input_value[@]}
		input_option "请输入kube-apiserver地址" "192.168.1.2:6443" apiserver_ip && apiserver_ip=${input_value[@]}
	fi
}

k8s_env_conf(){
	
	systemctl stop firewalld
	systemctl disable firewalld

	#关闭selinux
	system_optimize_selinux
	system_optimize_Limits
	system_optimize_kernel
}

k8s_install(){
	system_optimize_yum
	if [[ ${version_number} = '1.11' || ${version_number} = '1.12' || ${version_number} = '1.13' ]];then
		yum install -y kubectl-${online_select_version} kubeadm-${online_select_version} kubelet-${online_select_version} kubernetes-cni-0.6.0
	elif [[ ${version_number} = '1.14' ]];then
		yum install -y kubectl-${online_select_version} kubeadm-${online_select_version} kubelet-${online_select_version} kubernetes-cni-0.7.5
	fi
	if [[ $? = '0' ]];then
		diy_echo "kubectl kubeadm kubelet安装成功." "" "${info}"
		systemctl enable kubelet docker
		systemctl start docker
	else
		diy_echo "kubectl kubeadm kubelet安装失败!" "" "${error}"
		exit 1
	fi
}

k8s_mirror(){
	diy_echo "正在获取需要的镜像..." "" "${info}"
	if [[ ${node_type} = 'master' ]];then
		images_name=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube.*|pause.*|etcd.*|coredns.*' | awk -F : '{print $1}')
		tag=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube.*|pause.*|etcd.*|coredns.*' | awk -F : '{print $2}')
		images_name=(${images_name})
		tag=(${tag})
	else
		images_name=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube-proxy.*|pause.*' | awk -F : '{print $1}')
		tag=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube-proxy.*|pause.*' | awk -F : '{print $2}')
		images_name=(${images_name})
		tag=(${tag})
	fi
	
	if [[ ${version_number} = '1.11' ]];then
		platform=-amd64
	else
		platform=
	fi
	diy_echo "正在拉取需要的镜像..." "" "${info}"
	images_number=${#images_name[@]}
	#循环次数
	cycles=`expr ${images_number}-1`
	for ((i=0;i<=${cycles};i++))
	do
		docker pull rootww/${images_name[$i]}:${tag[$i]} || \
		docker pull mirrorgooglecontainers/${images_name[$i]}:${tag[$i]} && \
		docker tag rootww/${images_name[$i]}:${tag[$i]} k8s.gcr.io/${images_name[$i]}${platform}:${tag[$i]} || \
		docker tag mirrorgooglecontainers/${images_name[$i]}:${tag[$i]} k8s.gcr.io/${images_name[$i]}${platform}:${tag[$i]} && \
		docker rmi rootww/${images_name[$i]}:${tag[$i]} || \
		docker rmi mirrorgooglecontainers/${images_name[$i]}:${tag[$i]}
	done

}

k8s_conf_before(){
	
	#cgroup-driver驱动配置为和docker一致
	cgroup_driver=`docker info | grep 'Cgroup' | cut -d' ' -f3`
	KUBELET_EXTRA_ARGS="--fail-swap-on=false --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice --cgroup-driver=${cgroup_driver}"
	sed -i "s#KUBELET_EXTRA_ARGS=.*#KUBELET_EXTRA_ARGS=\"${KUBELET_EXTRA_ARGS}\"#" /etc/sysconfig/kubelet

}

k8s_init_config(){
	get_ip
	wget -O /etc/kubernetes/kubeadm_init.yaml https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/kubeadm/init_config_${version_number}.yaml
	sed -i "s/name: 127.0.0.1/name: ${local_ip}/" /etc/kubernetes/kubeadm_init.yaml
	sed -i "s/advertiseAddress: 127.0.0.1/advertiseAddress: ${local_ip}/" /etc/kubernetes/kubeadm_init.yaml
	sed -i "s/kubernetesVersion: .*/kubernetesVersion: v${online_select_version}/" /etc/kubernetes/kubeadm_init.yaml

}

k8s_init(){

	if [[ ${node_type} = 'master' ]];then
		diy_echo "正在初始化k8s..." "" "${info}"
		kubeadm init --config /etc/kubernetes/kubeadm_init.yaml --ignore-preflight-errors=Swap --ignore-preflight-errors=SystemVerification >/dev/null
		if [[ $? = '0' ]];then
			diy_echo "初始化k8s成功." "" "${info}"
			mkdir -p $HOME/.kube
			\cp -r /etc/kubernetes/admin.conf $HOME/.kube/config

		else
			diy_echo "初始化k8s失败!" "" "${error}"
			diy_echo "使用kubectl reset重置" "${yellow}" "${info}"
			exit 1
		fi
	fi
	
	if [[ ${node_type} = 'node' ]];then
		kubeadm join --token ${tonken} ${apiserver_ip} --node-name=${local_ip} --ignore-preflight-errors=Swap --discovery-token-unsafe-skip-ca-verification
		if [[ $? = '0' ]];then
			diy_echo "加入k8s集群成功." "" "${info}"
		else
			diy_echo "加入k8s集群失败!" "" "${error}"
			diy_echo "使用kubeadm reset重置" "${yellow}" "${info}"
			exit 1
		fi
	fi
}

k8s_conf_after(){
	diy_echo "配置k8s命令自动补全" "" "${info}"
	if [[ -z $(cat ~/.bashrc | grep 'source <(kubectl completion bash)') ]];then
		echo "source <(kubectl completion bash)" >> ~/.bashrc
	fi

	if [[ $(yes_or_no ${k8s_master_pod}) = 0 ]];then
		diy_echo "配置k8s允许master节点部署pod" "" "${info}"
		kubectl taint nodes --all node-role.kubernetes.io/master-
	elif [[ $(yes_or_no ${k8s_master_pod}) = 1 ]];then
		diy_echo "配置k8s禁止master节点部署pod" "" "${info}"
		kubectl taint nodes ${local_ip} node-role.kubernetes.io/master=true:NoSchedule
	fi

}

k8s_apply(){

	if [[ ${k8s_net[@]} =~ 'flannel' ]];then
		diy_echo "正在添加flannel..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	fi
	if [[ ${k8s_module[@]} =~ 'dashboard' ]];then
		diy_echo "正在添加dashboard..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard-admin.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard-user.yaml
	fi
	if [[ ${k8s_module[@]} =~ 'metrics' ]];then
		diy_echo "正在添加metrics监控..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/auth-delegator.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/auth-reader.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-apiservice.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-server-deployment.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-server-service.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/resource-reader.yaml
	fi
	if [[ ${k8s_module[@]} =~ 'heapster' ]];then
		diy_echo "正在添加heapster监控..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/heapster/heapster.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/heapster/resource-reader.yaml
	fi

}

k8s_install_ctl(){
	install_version k8s
	install_selcet
	k8s_install_set
	k8s_env_check
	online_version
	k8s_env_conf
	k8s_install
	k8s_mirror
	k8s_conf_before
	k8s_init_config
	k8s_init
	k8s_conf_after
	k8s_apply
}