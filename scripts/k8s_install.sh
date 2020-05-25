#!/bin/bash

env_load(){
	. ${workdir}/config/k8s/k8s.conf
	auto_ssh_keygen
	tmp_dir=/tmp/install_tmp
	mkdir -p ${tmp_dir}/{soft,ssl,conf}
	cd ${tmp_dir}
	
	local i=0
	for host in ${host_name[@]};
	do
	scp -P ${ssh_port[i]} ${workdir}/scripts/{public.sh,system_optimize.sh} root@${host}:/root
	ssh ${host_name[$i]} -p ${ssh_port[$i]} "
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
	
	. /root/public.sh
	. /root/system_optimize.sh
	conf=(1 2 4 5 6 7)
	system_optimize_set
	yum install ipvsadm ipset jq sysstat conntrack libseccomp conntrack-tools socat -y
	rm -rf /root/public.sh /root/system_optimize.sh"
	((i++))
	done
	
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${node_ip[$j]}" || ${host} = "${master_ip[$j]}" ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			curl -Ls -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
			yum install -y docker-ce && mkdir /etc/docker"
			scp -P ${ssh_port[i]} ${workdir}/config/k8s/daemon.json root@${host}:/etc/docker/daemon.json
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "systemctl start docker && systemctl enable docker"
			((j++))
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
		sed -i "/"127.0.0.1"/i\    \"${ip}\"," ${workdir}/config/k8s/etcd-csr.json
	done
	
	for ip in ${master_ip[*]}
	do
		sed -i "/\"127.0.0.1\"/i\    \"${ip}\"," ${workdir}/config/k8s/kube-scheduler-csr.json
		sed -i "/\"127.0.0.1\"/i\    \"${ip}\"," ${workdir}/config/k8s/kube-controller-manager-csr.json
		sed -i "/\"127.0.0.1\",/i\    \"${ip}\"," ${workdir}/config/k8s/kubernetes-csr.json
	done
	sed -i "/\"127.0.0.1\",/i\    \"${vip}\"," ${workdir}/config/k8s/kubernetes-csr.json
	
	cd ${tmp_dir}/ssl
	cfssl gencert -initca ${workdir}/config/k8s/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/etcd-csr.json | cfssljson -bare etcd
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/flanneld-csr.json | cfssljson -bare flanneld
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/admin-csr.json | cfssljson -bare admin
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kubernetes-csr.json | cfssljson -bare kubernetes
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-scheduler-csr.json | cfssljson -bare kube-scheduler
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-proxy-csr.json | cfssljson -bare kube-proxy
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/proxy-client-csr.json | cfssljson -bare proxy-client
	cd ..
}

down_k8s_file(){
	mkdir -p ${tmp_dir}/soft/cni
	down_file https://mirrors.huaweicloud.com/etcd/v${etcd_ver}/etcd-v${etcd_ver}-linux-amd64.tar.gz ${tmp_dir}/soft/etcd-v${etcd_ver}-linux-amd64.tar.gz
	down_file https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/kubernetes-server-linux-amd64.tar.gz ${tmp_dir}/soft/kubernetes-server-linux-amd64.tar.gz
	down_file https://github.com/containernetworking/plugins/releases/download/v${cni_ver}/cni-plugins-linux-amd64-v${cni_ver}.tgz ${tmp_dir}/soft/cni-plugins-linux-amd64-v${cni_ver}.tgz
	down_file https://download.fastgit.org/containernetworking/plugins/releases/download/v${cni_ver}/cni-plugins-linux-amd64-v${cni_ver}.tgz ${tmp_dir}/soft/cni-plugins-linux-amd64-v${cni_ver}.tgz

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
	listen-peer-urls: "https://${host_name[$i]}:2380"
	listen-client-urls: "https://${host_name[$i]}:2379,http://127.0.0.1:2379"
	#[Clustering]
	initial-advertise-peer-urls: "https://${host_name[$i]}:2380"
	advertise-client-urls: "https://${host_name[$i]}:2379"
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
	for host in ${host_name[@]};
	do
		if [[ "${etcd_ip[@]}" =~ ${host} ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl restart etcd.service" &
		fi
		((i++))
	done
}

etcd_check(){
	sleep 5
	local i=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${etcd_ip[0]}" ]];then
			healthy=`ssh ${host_name[$i]} -p ${ssh_port[$i]} "/opt/etcd/bin/etcdctl --ca-file=${etcd_dir}/ssl/ca.pem --cert-file=${etcd_dir}/ssl/etcd.pem --key-file=${etcd_dir}/ssl/etcd-key.pem --endpoints="https://${etcd_ip}:2379" cluster-health" | grep 'cluster is healthy' | wc -l`
			if [[ ${healthy} = '1' ]];then
				diy_echo "etcd集群状态正常" "${info}"
			else
				diy_echo "etcd集群状态不正常，请检查！！" "${red}" "${error}"
				exit 1
			fi
		fi
		((i++))
	done
}

get_etcd_cluster_ip(){
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${etcd_ip[@]} =~ ${host} ]];then
			etcd_cluster_ip=${etcd_cluster_ip}etcd-$j=https://${host_name[$i]}:2380,
			etcd_endpoints=${etcd_endpoints}https://${host_name[$i]}:2379,
			((j++))
		fi
		((i++))
	done
	#删除最后的逗号
	etcd_cluster_ip=${etcd_cluster_ip%,*}
	etcd_endpoints=${etcd_endpoints%,*}

}

add_system(){
	home_dir=${tmp_dir}
	##etcd
	Type="notify"
	initd="etcd_init"
	ExecStart="${etcd_dir}/bin/etcd --config-file=${etcd_dir}/cfg/etcd.yml"
	conf_system_service

	##apiserver
	ExecStartPost=
	Type="notify"
	initd="apiserver_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-apiserver"
	ExecStart="${k8s_dir}/bin/kube-apiserver \$KUBE_APISERVER_OPTS"
	conf_system_service
	##scheduler
	Type="simple"
	initd="scheduler_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-scheduler"
	ExecStart="${k8s_dir}/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS"
	conf_system_service
	##controller
	Type="simple"
	initd="controller_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-controller-manager"
	ExecStart="${k8s_dir}/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS"
	conf_system_service
	##proxy
	Type="simple"
	initd="proxy_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-proxy"
	ExecStart="${k8s_dir}/bin/kube-proxy \$KUBE_PROXY_OPTS"
	conf_system_service
	##proxy
	Type="simple"
	initd="kubelet_init"
	EnvironmentFile="${k8s_dir}/cfg/kubelet"
	ExecStart="${k8s_dir}/bin/kubelet \$KUBELET_OPTS"
	conf_system_service
}

etcd_install_ctl(){
	get_etcd_cluster_ip
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${etcd_ip[@]} =~ ${host} ]];then
			etcd_conf
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${etcd_dir}/{bin,cfg,ssl}"
			scp  -P ${ssh_port[i]} ${tmp_dir}/soft/etcd-v${etcd_ver}-linux-amd64/{etcd,etcdctl} root@${host}:${etcd_dir}/bin/
			scp  -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,etcd.pem,etcd-key.pem}  root@${host}:${etcd_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/conf/etcd.yml  root@${host}:${etcd_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd_init root@${host}:/etc/systemd/system/etcd.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload
			systemctl enable etcd"
			((j++))
		fi
		((i++))
	done
	etcd_start
	etcd_check
}

flannel_conf(){

	cat >${tmp_dir}/conf/flannel <<-EOF
	FLANNEL_OPTIONS="--etcd-endpoints=${etcd_endpoints} -etcd-cafile=${flannel_dir}/ssl/ca.pem -etcd-certfile=${flannel_dir}/ssl/flanneld.pem -etcd-keyfile=${flannel_dir}/ssl/flanneld-key.pem"
	EOF
}

flannel_install_ctl(){
	
	local i=0
	for host in ${host_name[@]};
	do
		if [[ "${node_ip[@]}" =~ ${host} ]];then
			flannel_conf
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${flannel_dir}/{bin,cfg,ssl}"
			scp  -P ${ssh_port[i]} ${tmp_dir}/soft/flannel/{flanneld,mk-docker-opts.sh} root@${host}:${flannel_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,flanneld.pem,flanneld-key.pem} root@${host}:${flannel_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/conf/flannel root@${host}:${flannel_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel_init root@${host}:/etc/systemd/system/flanneld.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "			
			[[ `grep EnvironmentFile=/run/flannel/docker /usr/lib/systemd/system/docker.service` = '' ]] && sed -i '/Type/a EnvironmentFile=\/run/flannel\/docker' /usr/lib/systemd/system/docker.service
			sed -i 's#ExecStart.*#ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock $DOCKER_NETWORK_OPTIONS#' /usr/lib/systemd/system/docker.service
			systemctl daemon-reload
			systemctl start flanneld docker.service"
		fi
		((i++))
	done

}

install_before_conf(){

	master_num=${#master_ip[@]}
	if [[ ${master_num} = '1' ]];then
		vip=${master_ip}
		api_service_ip="https://${vip}:6443"
	else
		api_service_ip="https://${vip}:8443"
	fi
	sed -i -e "s?192.168.0.0/16?10.244.0.0/16?g" ${workdir}/config/k8s/calico.yaml
	token_pub=$(openssl rand -hex 3)
	token_secret=$(openssl rand -hex 8)
	bootstrap_token="${token_pub}.${token_secret}"
}

apiserver_conf(){
	cat >${tmp_dir}/conf/kube-apiserver <<-EOF 
	
	KUBE_APISERVER_OPTS="--logtostderr=true \\
	--v=4 \\
	--etcd-servers=${etcd_endpoints} \\
	--bind-address=${host_name[$i]} \\
	--secure-port=6443 \\
	--advertise-address=${host_name[$i]} \\
	--allow-privileged=true \\
	--service-cluster-ip-range=10.96.0.0/12 \\
	--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction \\
	--authorization-mode=RBAC,Node \\
	--enable-bootstrap-token-auth \\
	--service-node-port-range=30000-50000 \\
	--tls-cert-file=${k8s_dir}/ssl/kubernetes.pem  \\
	--tls-private-key-file=${k8s_dir}/ssl/kubernetes-key.pem \\
	--client-ca-file=${k8s_dir}/ssl/ca.pem \\
	--service-account-key-file=${k8s_dir}/ssl/ca-key.pem \\
	--etcd-cafile=${k8s_dir}/ssl/ca.pem \\
	--etcd-certfile=${k8s_dir}/ssl/kubernetes.pem \\
	--etcd-keyfile=${k8s_dir}/ssl/kubernetes-key.pem"
	EOF

}

scheduler_conf(){
	cat >${tmp_dir}/conf/kube-scheduler <<-EOF 
	KUBE_SCHEDULER_OPTS="--logtostderr=true \\
	--v=4 \\
	--kubeconfig=${k8s_dir}/cfg/scheduler.kubeconfig \\
	--leader-elect=true"
	EOF
}

controller_manager_conf(){
	cat >${tmp_dir}/conf/kube-controller-manager <<-EOF 
	KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \\
	--v=4 \\
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
	--v=4 \\
	--hostname-override=${host_name[$i]} \\
	--config=${k8s_dir}/cfg/kubelet.yml \\
	--kubeconfig=${k8s_dir}/cfg/kubelet.kubeconfig \\
	--bootstrap-kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig \\
	--network-plugin=cni \\
	--cni-conf-dir=/etc/cni/net.d \\
	--cni-bin-dir=/opt/cni/bin \\
	--cert-dir=${k8s_dir}/ssl \\
	--fail-swap-on=false \\
	--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
	EOF

}

proxy_conf(){

	cat > ${tmp_dir}/conf/kube-proxy  <<-EOF
	KUBE_PROXY_OPTS="--logtostderr=true \\
	--v=4 \\
	--hostname-override=${host_name[$i]} \\
	--cluster-cidr=10.244.0.0/16 \\
	--kubeconfig=${k8s_dir}/cfg/kube-proxy.kubeconfig"
	EOF
}

master_install_ctl(){
	
	local i=0
	for host in ${host_name[@]};
	do
		if [[ "${master_ip[@]}" =~ ${host} ]];then
			apiserver_conf
			scheduler_conf
			controller_manager_conf
			kubelet_conf
			proxy_conf
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${k8s_dir}/{bin,cfg,ssl,yml}"
			scp  -P ${ssh_port[i]} ${tmp_dir}/soft/kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubectl,kubelet,kube-proxy} root@${host}:${k8s_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,kubernetes.pem,kubernetes-key.pem,kube-controller-manager.pem,kube-controller-manager-key.pem,kube-scheduler.pem,kube-scheduler-key.pem,admin.pem,admin-key.pem,kube-proxy.pem,kube-proxy-key.pem}  root@${host}:${k8s_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/conf/{kube-apiserver,kube-scheduler,kube-controller-manager,kube-proxy,kubelet,kubelet.yml}  root@${host}:${k8s_dir}/cfg
			scp  -P ${ssh_port[i]} ${workdir}/config/k8s/{auto-approve-node.yml,calico.yaml,corends.yaml}  root@${host}:${k8s_dir}/yml
			scp  -P ${ssh_port[i]} ${tmp_dir}/apiserver_init root@${host}:/etc/systemd/system/kube-apiserver.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/scheduler_init root@${host}:/etc/systemd/system/kube-scheduler.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/controller_init root@${host}:/etc/systemd/system/kube-controller-manager.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/proxy_init root@${host}:/etc/systemd/system/kube-proxy.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/kubelet_init root@${host}:/etc/systemd/system/kubelet.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload
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
			
			systemctl restart kube-apiserver kube-scheduler kube-controller-manager && systemctl enable kube-apiserver kube-scheduler kube-controller-manager
			systemctl restart kube-proxy kubelet && systemctl enable kube-proxy kubelet
			sleep 10
			"
		fi
		((i++))
	done

}

node_install_ctl(){
	local i=0
	for host in ${host_name[@]};
	do
		if [[ "${node_ip[@]}" =~ ${host} ]];then
			kubelet_conf
			proxy_conf
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${k8s_dir}/{bin,cfg,ssl}"
			scp  -P ${ssh_port[i]} ${tmp_dir}/soft/kubernetes/server/bin/{kube-proxy,kubelet,kubectl} root@${host}:${k8s_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/ssl/{ca.pem,ca-key.pem,kube-proxy.pem,kube-proxy-key.pem}  root@${host}:${k8s_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/conf/{kube-proxy,kubelet,kubelet.yml}  root@${host}:${k8s_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/proxy_init root@${host}:/etc/systemd/system/kube-proxy.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/kubelet_init root@${host}:/etc/systemd/system/kubelet.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload
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
			
			systemctl restart kube-proxy kubelet && systemctl enable kube-proxy kubelet
			sleep 10
			"
		fi
		((i++))
	done
	

}

master_node_check(){
	local i=0
	for host in ${host_name[@]};
	do
		if [[ "${master_ip[*]}" =~ ${host} ]];then
			healthy=`ssh ${host_name[$i]} -p ${ssh_port[$i]} "${k8s_dir}/bin/kubectl get cs | grep scheduler | grep Unhealthy | awk '{print $2}' | wc -l"`
			[[ $healthy = '1' ]] && diy_echo "主机${host_name[$i]}k8s组件scheduler状态异常！！！" "$red" "$error"
			healthy=`ssh ${host_name[$i]} -p ${ssh_port[$i]} "${k8s_dir}/bin/kubectl get cs | grep controller-manager | grep Unhealthy | awk '{print $2}' | wc -l"`
			[[ $healthy = '1' ]] && diy_echo "主机${host_name[$i]}k8s组件controller-manage状态异常！！！" "$red" "$error"
			healthy=`ssh ${host_name[$i]} -p ${ssh_port[$i]} "${k8s_dir}/bin/kubectl get cs | grep etcd | grep Healthy | awk '{print $2}' | wc -l"`
			[[ $healthy = '0' ]] && diy_echo "k8s组件etcd状态异常！！！" "$red" "$error"
		fi
		((i++))
	done
}

culster_bootstrap_conf(){
	local i=0
	for host in ${host_name[@]};
	do
		if [[ "${master_ip[0]}" =~ ${host} ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			
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
	for host in ${host_name[@]};
	do
		if [[ "${master_ip[0]}" =~ ${host} ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/calico.yaml
			${k8s_dir}/bin/kubectl apply -f ${k8s_dir}/yml/corends.yaml
			${k8s_dir}/bin/kubectl label node ${master_ip[@]} node-role.kubernetes.io/master=""
			${k8s_dir}/bin/kubectl label node ${node_ip[@]} node-role.kubernetes.io/node=""
			"
		fi
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
	master_install_ctl
	master_node_check
	culster_bootstrap_conf
	node_install_ctl
	culster_other_conf
}
