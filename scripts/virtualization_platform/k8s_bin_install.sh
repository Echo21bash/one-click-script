#!/bin/bash
set -e

env_load(){
	vi ${workdir}/config/k8s/k8s.conf
	. ${workdir}/config/k8s/k8s.conf
	auto_ssh_keygen
	tmp_dir=/usr/local/src/k8s_install_tmp
	mkdir -p ${tmp_dir}/{soft,ssl,conf}
	cd ${tmp_dir}
	info_log "正在配置k8s基础环境......"
	local i=0
	for host in ${host_ip[@]};
	do
	scp -P ${ssh_port[i]} ${workdir}/scripts/public.sh root@${host}:/tmp
	scp -P ${ssh_port[i]} ${workdir}/scripts/other/system_optimize.sh root@${host}:/tmp
	ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
	cat >/etc/modules-load.d/10-k8s-modules.conf<<-EOF
	br_netfilter
	ip_vs
	ip_vs_rr
	ip_vs_wrr
	ip_vs_sh
	nf_conntrack_ipv4
	nf_conntrack
	EOF
	modprobe br_netfilter
	modprobe ip_vs
	modprobe ip_vs_rr
	modprobe ip_vs_wrr
	modprobe ip_vs_sh
	modprobe nf_conntrack_ipv4
	modprobe nf_conntrack
	cat >/etc/sysctl.d/95-k8s-sysctl.conf<<-EOF
	net.ipv4.ip_forward = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-arptables = 1
	EOF
	sysctl -p /etc/sysctl.d/95-k8s-sysctl.conf >/dev/null
	. /tmp/public.sh
	. /tmp/system_optimize.sh
	system_optimize_set
	yum install bash-completion ipvsadm ipset jq conntrack libseccomp conntrack-tools socat -y
	"
	((i++))
	done
	
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${node_ip[@]}" =~ ${host} || "${master_ip[@]}" =~ ${host} ]];then
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			curl -Ls -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
			yum install -y docker-ce && mkdir /etc/docker"
			scp -P ${ssh_port[i]} ${workdir}/config/docker/daemon.json root@${host}:/etc/docker/daemon.json
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "systemctl start docker && systemctl enable docker"
		fi
		((i++))
	done
}

install_cfssl(){
	down_file https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 /usr/local/bin/cfssl
	down_file https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 /usr/local/bin/cfssljson
	down_file https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
	chmod +x /usr/local/bin/cfssl*

}

create_ca(){
	for ip in ${etcd_ip[*]}
	do
		[[ -z `grep ${ip} ${workdir}/config/k8s/certs/etcd-csr.json` ]] && sed -i "/"127.0.0.1"/i\    \"${ip}\"," ${workdir}/config/k8s/certs/etcd-csr.json
	done
	
	for ip in ${master_ip[*]}
	do
		[[ -z `grep ${ip} ${workdir}/config/k8s/certs/kube-scheduler-csr.json` ]] && sed -i "/\"127.0.0.1\"/i\    \"${ip}\"," ${workdir}/config/k8s/certs/kube-scheduler-csr.json
		[[ -z `grep ${ip} ${workdir}/config/k8s/certs/kube-controller-manager-csr.json` ]] && sed -i "/\"127.0.0.1\"/i\    \"${ip}\"," ${workdir}/config/k8s/certs/kube-controller-manager-csr.json
		[[ -z `grep ${ip} ${workdir}/config/k8s/certs/kubernetes-csr.json` ]] && sed -i "/\"127.0.0.1\",/i\    \"${ip}\"," ${workdir}/config/k8s/certs/kubernetes-csr.json
		
		if [[ -n ${vip} ]];then
			[[ -z `grep ${vip} ${workdir}/config/k8s/certs/kube-scheduler-csr.json` ]] && sed -i "/\"127.0.0.1\"/i\    \"${vip}\"," ${workdir}/config/k8s/certs/kube-scheduler-csr.json
			[[ -z `grep ${vip} ${workdir}/config/k8s/certs/kube-controller-manager-csr.json` ]] && sed -i "/\"127.0.0.1\"/i\    \"${vip}\"," ${workdir}/config/k8s/certs/kube-controller-manager-csr.json
			[[ -z `grep ${vip} ${workdir}/config/k8s/certs/kubernetes-csr.json` ]] && sed -i "/\"127.0.0.1\",/i\    \"${vip}\"," ${workdir}/config/k8s/certs/kubernetes-csr.json
		fi

	done

	
	
	cd ${tmp_dir}/ssl
	info_log "正在创建所需的证书......"
	cfssl gencert -initca ${workdir}/config/k8s/certs/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/etcd-csr.json | cfssljson -bare etcd
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/admin-csr.json | cfssljson -bare admin
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/kubernetes-csr.json | cfssljson -bare kubernetes
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/kube-scheduler-csr.json | cfssljson -bare kube-scheduler
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/kube-proxy-csr.json | cfssljson -bare kube-proxy
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/certs/ca-config.json -profile=kubernetes ${workdir}/config/k8s/certs/proxy-client-csr.json | cfssljson -bare proxy-client
	cd ..
}

down_k8s_file(){
	mkdir -p ${tmp_dir}/soft/cni
	down_file https://mirrors.huaweicloud.com/etcd/v${etcd_ver}/etcd-v${etcd_ver}-linux-amd64.tar.gz ${tmp_dir}/soft/etcd-v${etcd_ver}-linux-amd64.tar.gz
	down_file https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/kubernetes-server-linux-amd64.tar.gz ${tmp_dir}/soft/kubernetes-server-linux-amd64.tar.gz
	down_file https://github.com/containernetworking/plugins/releases/download/v${cni_ver}/cni-plugins-linux-amd64-v${cni_ver}.tgz ${tmp_dir}/soft/cni-plugins-linux-amd64-v${cni_ver}.tgz
	diy_echo "正在解压文件中..." "${info}"
	cd ${tmp_dir}/soft
	tar -zxf etcd-v${etcd_ver}-linux-amd64.tar.gz
	tar -zxf kubernetes-server-linux-amd64.tar.gz
	tar -zxf cni-plugins-linux-amd64-v${cni_ver}.tgz -C ${tmp_dir}/soft/cni
	cd ..
}

etcd_conf(){
	
	cat >${tmp_dir}/conf/etcd.yml <<-EOF
	#[Member]
	name: "etcd-$j"
	data-dir: "${etcd_data_dir}"
	listen-peer-urls: "https://${host_ip[$i]}:2380"
	listen-client-urls: "https://${host_ip[$i]}:2379,http://127.0.0.1:2379"
	#[Clustering]
	initial-advertise-peer-urls: "https://${host_ip[$i]}:2380"
	advertise-client-urls: "https://${host_ip[$i]}:2379"
	initial-cluster: "${etcd_cluster_ip}"
	initial-cluster-token: "etcd-cluster"
	initial-cluster-state: "new"
	peer-transport-security:
	 cert-file: "${etcd_dir}/ssl/etcd.pem"
	 key-file: "${etcd_dir}/ssl/etcd-key.pem"
	 peer-cert-file: "${etcd_dir}/ssl/etcd.pem"
	 peer-key-file: "${etcd_dir}/ssl/etcd-key.pem"
	 trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	 peer-trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	client-transport-security:
	 cert-file: "${etcd_dir}/ssl/etcd.pem"
	 key-file: "${etcd_dir}/ssl/etcd-key.pem"
	 peer-cert-file: "${etcd_dir}/ssl/etcd.pem"
	 peer-key-file: "${etcd_dir}/ssl/etcd-key.pem"
	 trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	 peer-trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	EOF

}

etcd_start(){
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${etcd_ip[@]}" =~ ${host} ]];then
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			service_control etcd restart" &
		fi
		((i++))
	done
}

etcd_check(){
	info_log "正在检查etcd集群服务是否正常..."
	sleep 5
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ ${host} = "${etcd_ip[0]}" ]];then
			healthy=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "${etcd_dir}/bin/etcdctl --ca-file=${etcd_dir}/ssl/ca.pem --cert-file=${etcd_dir}/ssl/etcd.pem --key-file=${etcd_dir}/ssl/etcd-key.pem --endpoints="https://${etcd_ip}:2379" cluster-health" | grep 'cluster is healthy' | wc -l`
			if [[ ${healthy} = '1' ]];then
				info_log "etcd集群状态正常"
			else
				error_log "etcd集群状态不正常，请检查！！"
				exit 1
			fi
		fi
		((i++))
	done
}

get_etcd_cluster_ip(){
	local i=0
	local j=0
	for host in ${host_ip[@]};
	do
		if [[ ${etcd_ip[@]} =~ ${host} ]];then
			etcd_cluster_ip=${etcd_cluster_ip}etcd-$j=https://${host_ip[$i]}:2380,
			etcd_endpoints=${etcd_endpoints}https://${host_ip[$i]}:2379,
			((j++))
		fi
		((i++))
	done
	#删除最后的逗号
	etcd_cluster_ip=${etcd_cluster_ip%,*}
	etcd_endpoints=${etcd_endpoints%,*}

}

add_system(){

	##etcd
	Type="notify"
	ExecStart="${etcd_dir}/bin/etcd --config-file=${etcd_dir}/cfg/etcd.yml"
	add_daemon_file ${tmp_dir}/etcd.service

	##apiserver
	ExecStartPost=
	Type="notify"
	EnvironmentFile="${k8s_dir}/cfg/kube-apiserver"
	ExecStart="${k8s_dir}/bin/kube-apiserver \$KUBE_APISERVER_OPTS"
	add_daemon_file ${tmp_dir}/kube-apiserver.service
	##scheduler
	Type="simple"
	EnvironmentFile="${k8s_dir}/cfg/kube-scheduler"
	ExecStart="${k8s_dir}/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS"
	add_daemon_file ${tmp_dir}/kube-scheduler.service
	##controller
	Requires='kube-apiserver.service'
	Type="simple"
	EnvironmentFile="${k8s_dir}/cfg/kube-controller-manager"
	ExecStart="${k8s_dir}/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS"
	add_daemon_file ${tmp_dir}/kube-controller-manager.service
	##proxy
	Requires=''
	Type="simple"
	EnvironmentFile="${k8s_dir}/cfg/kube-proxy"
	ExecStart="${k8s_dir}/bin/kube-proxy \$KUBE_PROXY_OPTS"
	add_daemon_file ${tmp_dir}/kube-proxy.service
	##proxy
	Type="simple"
	EnvironmentFile="${k8s_dir}/cfg/kubelet"
	ExecStart="${k8s_dir}/bin/kubelet \$KUBELET_OPTS"
	add_daemon_file ${tmp_dir}/kubelet.service

}

etcd_install_ctl(){
	get_etcd_cluster_ip
	local i=0
	local j=0
	for host in ${host_ip[@]};
	do
		if [[ ${etcd_ip[@]} =~ ${host} ]];then
			etcd_conf
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			[[ `service_control etcd is-exist` = 'exist' ]] && service_control etcd stop
			rm -rf ${etcd_data_dir}/*
			mkdir -p ${etcd_dir}/{bin,cfg,ssl}"
			scp -P ${ssh_port[i]} ${workdir}/scripts/public.sh root@${host}:/tmp
			scp -P ${ssh_port[i]} ${tmp_dir}/soft/etcd-v${etcd_ver}-linux-amd64/{etcd,etcdctl} root@${host}:${etcd_dir}/bin
			scp -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,etcd.pem,etcd-key.pem}  root@${host}:${etcd_dir}/ssl
			scp -P ${ssh_port[i]} ${tmp_dir}/conf/etcd.yml  root@${host}:${etcd_dir}/cfg
			scp -P ${ssh_port[i]} ${tmp_dir}/etcd.service root@${host}:/etc/systemd/system/etcd.service
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			service_control etcd enable
			"
			((j++))
		fi
		((i++))
	done
	etcd_start
	etcd_check
}

install_before_conf(){

	master_num=${#master_ip[@]}
	if [[ -n ${vip} ]];then
		api_service_ip="https://${vip}:${vip_port}"
	else
		api_service_ip="https://${master_ip}:6443"
	fi
	sed -i -e "s?192.168.0.0/16?10.244.0.0/16?g" ${workdir}/config/k8s/yml/calico.yaml
	token_pub=$(openssl rand -hex 3)
	token_secret=$(openssl rand -hex 8)
	bootstrap_token="${token_pub}.${token_secret}"
}

create_hosts_file(){
	###创建hosts文件
	rm -rf ${tmp_dir}/hosts
	echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >> ${tmp_dir}/hosts
	echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ${tmp_dir}/hosts
	local j=1
	local k=1
	for host in ${host_ip[@]};
	do
		if [[ "${master_ip[@]}" =~ ${host} ]];then
			echo "${host}  k8s-master${j}" >> ${tmp_dir}/hosts
			((j++))
		fi
		if [[ "${node_ip[@]}" =~ ${host} ]];then
			echo "${host}  k8s-worker${k}" >> ${tmp_dir}/hosts
			((k++))
		fi
	done

}

apiserver_conf(){
	cat >${tmp_dir}/conf/kube-apiserver <<-EOF 
	
	KUBE_APISERVER_OPTS="--logtostderr=true \\
	--v=2 \\
	--etcd-servers=${etcd_endpoints} \\
	--bind-address=${host_ip[$i]} \\
	--secure-port=6443 \\
	--advertise-address=${host_ip[$i]} \\
	--allow-privileged=true \\
	--service-cluster-ip-range=10.96.0.0/12 \\
	--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction \\
	--authorization-mode=RBAC,Node \\
	--enable-bootstrap-token-auth \\
	--enable-aggregator-routing=true \\
	--requestheader-client-ca-file=${k8s_dir}/ssl/ca.pem \\
	--requestheader-allowed-names=aggregator,metrics-server \\
	--requestheader-extra-headers-prefix=X-Remote-Extra- \\
	--requestheader-group-headers=X-Remote-Group \\
	--requestheader-username-headers=X-Remote-User \\
	--service-node-port-range=30000-50000 \\
	--tls-cert-file=${k8s_dir}/ssl/kubernetes.pem  \\
	--tls-private-key-file=${k8s_dir}/ssl/kubernetes-key.pem \\
	--client-ca-file=${k8s_dir}/ssl/ca.pem \\
	--service-account-key-file=${k8s_dir}/ssl/ca-key.pem \\
	--etcd-cafile=${k8s_dir}/ssl/ca.pem \\
	--etcd-certfile=${k8s_dir}/ssl/kubernetes.pem \\
	--etcd-keyfile=${k8s_dir}/ssl/kubernetes-key.pem \\
	--proxy-client-cert-file=${k8s_dir}/ssl/proxy-client.pem \\
	--proxy-client-key-file=${k8s_dir}/ssl/proxy-client-key.pem \\
	--kubelet-client-certificate=${k8s_dir}/ssl/kubernetes.pem \\
	--kubelet-client-key=${k8s_dir}/ssl/kubernetes-key.pem "
	EOF

}

scheduler_conf(){
	cat >${tmp_dir}/conf/kube-scheduler <<-EOF 
	KUBE_SCHEDULER_OPTS="--logtostderr=true \\
	--v=2 \\
	--kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig \\
	--leader-elect=true"
	EOF
}

controller_manager_conf(){
	cat >${tmp_dir}/conf/kube-controller-manager <<-EOF 
	KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \\
	--v=2 \\
	--bind-address=127.0.0.1 \\
	--kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig \\
	--authentication-kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig \\
	--authorization-kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig \\
	--leader-elect=true \\
	--service-cluster-ip-range=10.96.0.0/12 \\
	--cluster-cidr=10.244.0.0/16 \\
	--use-service-account-credentials=true \\
	--controllers=*,bootstrapsigner,tokencleaner \\
	--experimental-cluster-signing-duration=86700h \\
	--feature-gates=RotateKubeletClientCertificate=true \\
	--cluster-signing-cert-file=${k8s_dir}/ssl/ca.pem \\
	--cluster-signing-key-file=${k8s_dir}/ssl/ca-key.pem  \\
	--requestheader-client-ca-file=${k8s_dir}/ssl/ca.pem \\
	--service-account-private-key-file=${k8s_dir}/ssl/ca-key.pem"
	EOF
}

kubelet_conf(){
	cat > ${tmp_dir}/conf/kubelet.yml <<-EOF
	kind: KubeletConfiguration
	address: 0.0.0.0
	apiVersion: kubelet.config.k8s.io/v1beta1
	authentication:
	  anonymous:
	    enabled: false
	  webhook:
	    cacheTTL: 2m0s
	    enabled: true
	  x509:
	    clientCAFile: ${k8s_dir}/ssl/ca.pem
	authorization:
	  mode: Webhook
	  webhook:
	    cacheAuthorizedTTL: 5m0s
	    cacheUnauthorizedTTL: 30s
	cgroupDriver: cgroupfs
	cgroupsPerQOS: true
	clusterDNS:
	- 10.96.0.10
	clusterDomain: cluster.local
	EOF
	
	cat > ${tmp_dir}/conf/kubelet <<-EOF
	KUBELET_OPTS="--logtostderr=true \\
	--v=2 \\
	--hostname-override=${hostname} \\
	--config=${k8s_dir}/cfg/kubelet.yml \\
	--kubeconfig=${k8s_dir}/cfg/kubelet.kubeconfig \\
	--bootstrap-kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig \\
	--network-plugin=cni \\
	--cni-conf-dir=/etc/cni/net.d \\
	--cni-bin-dir=/opt/cni/bin \\
	--cert-dir=${k8s_dir}/ssl \\
	--fail-swap-on=false \\
	--runtime-cgroups=/systemd/system.slice \\
	--kubelet-cgroups=/systemd/system.slice \\
	--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
	EOF

}

proxy_conf(){
	if [[ ${k8s_ver} > 1.8.0 ]];then
		cat > ${tmp_dir}/conf/kube-proxy  <<-EOF
		KUBE_PROXY_OPTS="--logtostderr=true \\
		--v=2 \\
		--hostname-override=${hostname} \\
		--proxy-mode=ipvs \\
		--cluster-cidr=10.244.0.0/16 \\
		--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig"
		EOF
	else
		cat > ${tmp_dir}/conf/kube-proxy  <<-EOF
		KUBE_PROXY_OPTS="--logtostderr=true \\
		--v=2 \\
		--hostname-override=${hostname} \\
		--cluster-cidr=10.244.0.0/16 \\
		--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig"
		EOF
	fi
}

master_node_install_ctl(){
	
	local i=0
	local j=1
	for host in ${host_ip[@]};
	do
		if [[ "${master_ip[@]}" =~ ${host} ]];then
			hostname="k8s-master${j}"
			apiserver_conf
			scheduler_conf
			controller_manager_conf
			kubelet_conf
			proxy_conf
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			[[ `service_control kube-apiserver is-exist` = 'exist' ]] && service_control kube-apiserver stop
			[[ `service_control kube-scheduler is-exist` = 'exist' ]] && service_control kube-scheduler stop
			[[ `service_control kube-controller-manager is-exist` = 'exist' ]] && service_control kube-controller-manager stop
			[[ `service_control kube-proxy is-exist` = 'exist' ]] && service_control kube-proxy stop
			[[ `service_control kubelet is-exist` = 'exist' ]] && service_control kubelet stop
			rm -rf ${k8s_dir}/ssl/*
			hostnamectl set-hostname k8s-master${j}
			mkdir -p ${k8s_dir}/{bin,cfg,ssl,yml}"
			info_log "正在向主节点${host_ip[i]}分发k8s程序及配置文件..."
			scp -P ${ssh_port[i]} ${tmp_dir}/soft/kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubectl,kubelet,kube-proxy} root@${host}:${k8s_dir}/bin
			scp -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,kubernetes.pem,kubernetes-key.pem,kube-controller-manager.pem,kube-controller-manager-key.pem,kube-scheduler.pem,kube-scheduler-key.pem,admin.pem,admin-key.pem,kube-proxy.pem,kube-proxy-key.pem,proxy-client.pem,proxy-client-key.pem}  root@${host}:${k8s_dir}/ssl
			scp -P ${ssh_port[i]} ${tmp_dir}/conf/{kube-apiserver,kube-scheduler,kube-controller-manager,kube-proxy,kubelet,kubelet.yml}  root@${host}:${k8s_dir}/cfg
			scp -P ${ssh_port[i]} ${tmp_dir}/{kube-apiserver.service,kube-scheduler.service,kube-controller-manager.service,kube-proxy.service,kubelet.service} root@${host}:/etc/systemd/system
			scp -P ${ssh_port[i]} ${tmp_dir}/hosts root@${host}:/etc/hosts
			scp -P ${ssh_port[i]} ${workdir}/config/k8s/yml/{auto-approve-node.yml,calico.yaml,corends.yaml,metrics-server.yaml}  root@${host}:${k8s_dir}/yml
			info_log "正在生成主节点${host_ip[i]}kubeconfig配置文件..."
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			#利用证书生成kubectl的kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=/root/.kube/config
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials admin \
			--client-certificate=${k8s_dir}/ssl/admin.pem \
			--client-key=${k8s_dir}/ssl/admin-key.pem \
			--embed-certs=true \
			--kubeconfig=/root/.kube/config
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context kubernetes \
			--cluster=kubernetes \
			--user=admin \
			--kubeconfig=/root/.kube/config
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context kubernetes --kubeconfig=/root/.kube/config
			
			#利用证书生成controller-manager的kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials system:kube-controller-manager \
			--client-certificate=${k8s_dir}/ssl/kube-controller-manager.pem \
			--client-key=${k8s_dir}/ssl/kube-controller-manager-key.pem \
			--embed-certs=true \
			--kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context kubernetes \
			--cluster=kubernetes \
			--user=system:kube-controller-manager \
			--kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context kubernetes --kubeconfig=${k8s_dir}/cfg/controller-manager.kubeconfig
			
			#利用证书生成scheduler的kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials system:kube-scheduler \
			--client-certificate=${k8s_dir}/ssl/kube-scheduler.pem \
			--client-key=${k8s_dir}/ssl/kube-scheduler-key.pem \
			--embed-certs=true \
			--kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context kubernetes \
			--cluster=kubernetes \
			--user=system:kube-scheduler \
			--kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context kubernetes --kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig
			
			#创建kube-proxy.kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials system:kube-proxy \
			--client-certificate=${k8s_dir}/ssl/kube-proxy.pem \
			--client-key=${k8s_dir}/ssl/kube-proxy-key.pem \
			--embed-certs=true \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context default \
			--cluster=kubernetes \
			--user=system:kube-proxy \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context default --kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#创建bootstrap.kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials kubelet-bootstrap \
			--token=${bootstrap_token} \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context default \
			--cluster=kubernetes \
			--user=kubelet-bootstrap \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context default --kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig

			service_control kube-apiserver enable
			service_control kube-scheduler enable
			service_control kube-controller-manager enable
			service_control kube-proxy enable
			service_control kubelet enable
			service_control kube-apiserver restart
			service_control kube-scheduler restart
			service_control kube-controller-manager restart
			service_control kube-proxy restart
			service_control kubelet restart
			"
			((j++))
		fi
		((i++))
	done

}

work_node_install_ctl(){
	local i=0
	local j=1
	for host in ${host_ip[@]};
	do
		if [[ "${node_ip[@]}" =~ ${host} ]];then
			hostname="k8s-worker${j}"
			kubelet_conf
			proxy_conf
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			[[ `service_control kube-proxy is-exist` = 'exist' ]] && service_control kube-proxy stop
			[[ `service_control kubelet is-exist` = 'exist' ]] && service_control kubelet stop
			rm -rf ${k8s_dir}/ssl/*
			hostnamectl set-hostname k8s-worker${j}
			mkdir -p ${k8s_dir}/{bin,cfg,ssl}"
			info_log "正在向工作节点${host_ip[i]}分发k8s程序及配置文件..."
			scp -P ${ssh_port[i]} ${tmp_dir}/soft/kubernetes/server/bin/{kube-proxy,kubelet,kubectl} root@${host}:${k8s_dir}/bin
			scp -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,kube-proxy.pem,kube-proxy-key.pem}  root@${host}:${k8s_dir}/ssl
			scp -P ${ssh_port[i]} ${tmp_dir}/conf/{kube-proxy,kubelet,kubelet.yml}  root@${host}:${k8s_dir}/cfg
			scp -P ${ssh_port[i]} ${tmp_dir}/{kube-proxy.service,kubelet.service} root@${host}:/etc/systemd/system
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			. /tmp/public.sh
			#创建kube-proxy.kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials system:kube-proxy \
			--client-certificate=${k8s_dir}/ssl/kube-proxy.pem \
			--client-key=${k8s_dir}/ssl/kube-proxy-key.pem \
			--embed-certs=true \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context default \
			--cluster=kubernetes \
			--user=system:kube-proxy \
			--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context default --kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig
			
			#创建bootstrap.kubeconfig
			${k8s_dir}/bin/kubectl config set-cluster kubernetes \
			--certificate-authority=${k8s_dir}/ssl/ca.pem \
			--embed-certs=true \
			--server=${api_service_ip} \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置客户端认证参数
			${k8s_dir}/bin/kubectl config set-credentials kubelet-bootstrap \
			--token=${bootstrap_token} \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置上下文参数
			${k8s_dir}/bin/kubectl config set-context default \
			--cluster=kubernetes \
			--user=kubelet-bootstrap \
			--kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			#设置默认上下文
			${k8s_dir}/bin/kubectl config use-context default --kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig
			
			service_control kube-proxy enable
			service_control kubelet enable
			service_control kube-proxy restart
			service_control kubelet restart
			"
			((j++))
		fi
		((i++))
	done
	

}

master_node_check(){
	info_log "正在检查主节点各个服务是否正常..."
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${master_ip[*]}" =~ ${host} ]];then
			api_healthy=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "systemctl status kube-apiserver >/dev/null 2>&1  && echo 0"`
			[[ x$api_healthy = 'x' ]] && warning_log "主机${host_ip[$i]}k8s组件apiserver状态异常"
			scheduler_healthy=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "systemctl status kube-scheduler >/dev/null 2>&1  && echo 0"`
			[[ x$scheduler_healthy = 'x' ]] && warning_log "主机${host_ip[$i]}k8s组件scheduler状态异常"
			controller_healthy=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "systemctl status kube-controller-manager >/dev/null 2>&1  && echo 0"`
			[[ x$controller_healthy = 'x' ]] && warning_log "主机${host_ip[$i]}k8s组件controller-manager状态异常"
			etcd_healthy=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "${k8s_dir}/bin/kubectl get cs | grep etcd | grep Healthy | awk '{print $2}' | wc -l"`
			[[ $etcd_healthy = '0' ]] && diy_echo "k8s组件etcd状态异常！！！" "$red" "$error" && exit 1
		fi
		((i++))
	done

}

culster_bootstrap_conf(){
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${master_ip[0]}" =~ ${host} ]];then
		
			diy_echo "配置集群自动授权更新node节点证书" "${info}"
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			
			#将kubelet-bootstrap用户绑定到系统集群角色
			${k8s_dir}/bin/kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers
			#创建kubelet-bootstrap 证书
			${k8s_dir}/bin/kubectl -n kube-system create secret generic bootstrap-token-${token_pub} \
			--type 'bootstrap.kubernetes.io/token' \
			--from-literal description=\"cluster bootstrap token\" \
			--from-literal token-id=${token_pub} \
			--from-literal token-secret=${token_secret} \
			--from-literal usage-bootstrap-authentication=true \
			--from-literal usage-bootstrap-signing=true

			#自动approve csr请求(推荐)分别用于自动 approve client、renew client、renew server 证书
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/auto-approve-node.yml
			sleep 20
			"
		fi
		((i++))
	done

}

culster_other_conf(){

	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${master_ip[0]}" =~ ${host} ]];then
			diy_echo "部署网络插件打标签...以及其他配置" "${info}"
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			#授权 apiserver 调用 kubelet API
			${k8s_dir}/bin/kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/calico.yaml
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/corends.yaml
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/metrics-server.yaml
			sleep 30
			"
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			#给节点打标签
			${k8s_dir}/bin/kubectl get node | grep master | awk '{print\$1}' | xargs -I {} ${k8s_dir}/bin/kubectl label node {} node-role.kubernetes.io/master=""
			${k8s_dir}/bin/kubectl get node | grep work | awk '{print\$1}' | xargs -I {} ${k8s_dir}/bin/kubectl label node {} node-role.kubernetes.io/node=""
			#配置master节点禁止部署
			${k8s_dir}/bin/kubectl get node | grep master | awk '{print\$1}' | xargs -I {} ${k8s_dir}/bin/kubectl taint nodes {} node-role.kubernetes.io/master=:NoExecute
			"
		fi
		((i++))
	done
	
	local i=0
	for host in ${host_ip[@]};
	do
		if [[ "${node_ip[@]}" =~ ${host} || "${master_ip[@]}" =~ ${host} ]];then
			ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
			ln -sf ${k8s_dir}/bin/* /usr/local/bin/
			echo 'source <(kubectl completion bash)'>/etc/profile.d/k8s.sh
			"
		fi
		((i++))
	done
}

clean_tmpfile(){
	local i=0
	for host in ${host_ip[@]};
	do
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "rm -rf /tmp/public.sh /tmp/system_optimize.sh"
		((i++))
	done
}

k8s_bin_install(){
	env_load
	install_cfssl
	create_ca
	down_k8s_file
	add_system
	etcd_install_ctl
	install_before_conf
	create_hosts_file
	master_node_install_ctl
	master_node_check
	culster_bootstrap_conf
	work_node_install_ctl
	culster_other_conf
	clean_tmpfile
}
