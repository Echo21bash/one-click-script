#!/bin/bash

docker_install(){

	[[ -n `which docker 2>/dev/null` ]] && diy_echo "检测到可能已经安装docker请检查..." "${yellow}" "${warning}" && exit 1
	diy_echo "正在安装docker..." "" "${info}"
	system_optimize_yum
	if [[ ${os_release} < "7" ]];then
		yum install -y docker
	else
		down_file http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
		yum install -y docker-ce
	fi
	mkdir /etc/docker
	\cp ${workdir}/config/k8s/daemon.json root@${host}:/etc/docker
}


k8s_install_set(){

	output_option "选择安装方式" "kubeadm 二进制安装" install_method

}

k8s_set(){
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
	k8s_install_set
	if [[ ${install_method} = '1' ]];then
		k8s_set
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
	else
		k8s_bin_install
	fi

}