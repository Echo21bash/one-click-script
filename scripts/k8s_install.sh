#!/bin/bash

env_load(){
	. ${workdir}/config/k8s/k8s.conf
	auto_ssh_keygen
	tmp_dir=/tmp/install_tmp
	mkdir -p ${tmp_dir}
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
	system_optimize_set"
	((i++))
	done
	
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${node_ip[$j]}" ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			curl -Ls -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
			yum install -y docker-ce && mkdir /etc/docker"
			scp -P ${ssh_port[i]} ${workdir}/config/k8s/daemon.json root@${host}:/etc/docker
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

create_etcd_ca(){
	for ip in ${etcd_ip[*]}
	do
		sed -i "/"127.0.0.1"/i\    \"${ip}\"," ${workdir}/config/k8s/etcd-csr.json
	done
	
	for ip in ${master_ip[*]}
	do
		sed -i "/"127.0.0.1"/i\    \"${ip}\"," ${workdir}/config/k8s/kube-scheduler-csr.json
		sed -i "/"127.0.0.1"/i\    \"${ip}\"," ${workdir}/config/k8s/kube-controller-manager-csr.json
		sed -i "/"127.0.0.1",/i\    \"${ip}\"," ${workdir}/config/k8s/kubernetes-csr.json
	done
	
	cfssl gencert -initca ${workdir}/config/k8s/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/etcd-csr.json | cfssljson -bare etcd
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/flanneld-csr.json | cfssljson -bare flanneld
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/admin-csr.json | cfssljson -bare admin
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kubernetes-csr.json | cfssljson -bare kubernetes
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-scheduler-csr.json | cfssljson -bare kube-scheduler
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/kube-proxy-csr.json | cfssljson -bare kube-proxy
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=kubernetes ${workdir}/config/k8s/proxy-client-csr.json | cfssljson -bare proxy-client

}

down_k8s_file(){
	down_file https://mirrors.huaweicloud.com/etcd/v3.2.30/etcd-v3.2.30-linux-amd64.tar.gz ${tmp_dir}/etcd-v3.2.30-linux-amd64.tar.gz
	down_file https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz ${tmp_dir}/flannel-v0.10.0-linux-amd64.tar.gz
	down_file https://download.fastgit.org/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz ${tmp_dir}/flannel-v0.10.0-linux-amd64.tar.gz
	down_file https://storage.googleapis.com/kubernetes-release/release/v1.15.6/kubernetes-server-linux-amd64.tar.gz ${tmp_dir}/kubernetes-server-linux-amd64.tar.gz
	tar -zxf etcd-v3.2.30-linux-amd64.tar.gz
	tar -zxf flannel-v0.10.0-linux-amd64.tar.gz
	tar -zxf kubernetes-server-linux-amd64.tar.gz

}

etcd_conf(){

	if [[ ${etcd_num} = '1' ]];then
		cat >${tmp_dir}/etcd.yml <<-EOF
		#[Member]
		name: "etcd-$j"
		data-dir: "${etcd_data_dir}"
		listen-peer-urls: "https://${etcd_ip[$i]}:2380"
		listen-client-urls: "https://${etcd_ip[$i]}:2379"
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
	fi


	if [[ ${etcd_num} > '1' ]];then
		cat >${tmp_dir}/etcd.yml <<-EOF
		#[Member]
		name: "etcd-$j"
		data-dir: "${etcd_data_dir}"
		listen-peer-urls: "https://${host_name[$i]}:2380"
		listen-client-urls: "https://${host_name[$i]}:2379"
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
	fi

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
	local i=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${etcd_ip[0]}" ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			/opt/etcd/bin/etcdctl --ca-file=${etcd_dir}/ssl/ca.pem --cert-file=${etcd_dir}/ssl/etcd.pem --key-file=${etcd_dir}/ssl/etcd-key.pem --endpoints="https://${etcd_ip}:2379" cluster-health
			if [[ $? = '0' ]];then
				echo etcd集群可用
				${etcd_dir}/bin/etcdctl \
				--ca-file=${etcd_dir}/ssl/ca.pem --cert-file=${etcd_dir}/ssl/etcd.pem --key-file=${etcd_dir}/ssl/etcd-key.pem \
				--endpoints="${etcd_endpoints}" \
				set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
			else
				echo etcd集群不可用
				exit
			fi"
		fi
		((i++))
	done
}

get_etcd_cluster_ip(){

	etcd_num=${#etcd_ip[*]}
	local i=0
	for ((i=0;i<${etcd_num};i++));
	do
		etcd_cluster_ip=${etcd_cluster_ip}etcd-$i=https://${etcd_ip[$i]}:2380,
		etcd_endpoints=${etcd_endpoints}https://${etcd_ip[$i]}:2379,
	done
}

add_system(){
	home_dir=${tmp_dir}
	##etcd
	Type="notify"
	initd="etcd_init"
	ExecStart="${etcd_dir}/bin/etcd --config-file=${etcd_dir}/cfg/etcd.yml"
	conf_system_service
	##flannel
	Type="notify"
	initd="flannel_init"
	EnvironmentFile="${flannel_dir}/cfg/flannel"
	ExecStart="${flannel_dir}/bin/flanneld --ip-masq \$FLANNEL_OPTIONS"
	ExecStartPost="${flannel_dir}/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker"
	conf_system_service
	##apiserver
	Type="notify"
	initd="apiserver_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-apiserver"
	ExecStart="${k8s_dir}/bin/kube-apiserver \$KUBE_APISERVER_OPTS"
	conf_system_service
	##scheduler
	#Type="notify"
	initd="scheduler_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-scheduler"
	ExecStart="${k8s_dir}/bin/kube-apiserver \$$KUBE_SCHEDULER_OPTS"
	conf_system_service
	##controller
	#Type="notify"
	initd="controller_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-controller-manager"
	ExecStart="${k8s_dir}/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS"
	conf_system_service
	##proxy
	#Type="notify"
	initd="proxy_init"
	EnvironmentFile="${k8s_dir}/cfg/kube-controller-manager"
	ExecStart="${k8s_dir}/bin/kube-proxy \$KUBE_PROXY_OPTS"
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
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd-v3.2.30-linux-amd64/{etcd,etcdctl} root@${host}:${etcd_dir}/bin/
			scp  -P ${ssh_port[i]} ${tmp_dir}/{ca.pem,ca-key.pem,etcd.pem,etcd-key.pem}  root@${host}:${etcd_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd.yml  root@${host}:${etcd_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd_init root@${host}:/etc/systemd/system/etcd.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload"
			((j++))
		fi
		((i++))
	done
	etcd_start
	etcd_check
}

flannel_conf(){

	cat >${tmp_dir}/flannel <<-EOF
	FLANNEL_OPTIONS="--etcd-endpoints=${etcd_endpoints} -etcd-cafile=${flannel_dir}/ssl/ca.pem -etcd-certfile=${flannel_dir}/ssl/flannel.pem -etcd-keyfile=${flannel_dir}/ssl/flannel-key.pem"
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
			scp  -P ${ssh_port[i]} ${tmp_dir}/{flanneld,mk-docker-opts.sh} root@${host}:${flannel_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/{ca.pem,ca-key.pem,flanneld.pem,flanneld-key.pem} root@${host}:${flannel_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel root@${host}:${flannel_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel_init root@${host}:/etc/systemd/system/flanneld.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "			
			sed -i '/Type/a EnvironmentFile=\/run/flannel\/docker' /usr/lib/systemd/system/docker.service			
			systemctl daemon-reload"
		fi
		((i++))
	done

}

apiserver_conf(){
	cat >${tmp_dir}/kube-apiserver <<-EOF 
	
	KUBE_APISERVER_OPTS="--logtostderr=true \
	--v=4 \
	--etcd-servers=${etcd_endpoints} \
	--bind-address={host_name[$i]} \
	--secure-port=6443 \
	--advertise-address={host_name[$i]} \
	--allow-privileged=true \
	--service-cluster-ip-range=10.0.0.0/24 \
	--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction \
	--authorization-mode=RBAC,Node \
	--enable-bootstrap-token-auth \
	--token-auth-file=/opt/kubernetes/cfg/token.csv \
	--service-node-port-range=30000-50000 \
	--tls-cert-file=${k8s_dir}/ssl/kubernetes.pem  \
	--tls-private-key-file=${k8s_dir}/ssl/kubernetes-key.pem \
	--client-ca-file=${k8s_dir}/ssl/ca.pem \
	--service-account-key-file=${k8s_dir}/ssl/ca-key.pem \
	--etcd-cafile=${k8s_dir}/ssl/ca.pem \
	--etcd-certfile=${k8s_dir}/ssl/kubernetes.pem \
	--etcd-keyfile=${k8s_dir}/ssl/kubernetes-key.pem"
	EOF

}

scheduler_conf(){
	cat >${tmp_dir}/kube-scheduler <<-EOF 
	KUBE_SCHEDULER_OPTS="--logtostderr=true \
	--v=4 \
	--master=127.0.0.1:8080 \
	--leader-elect"
	EOF
}

controller_manager_conf(){
	cat >${tmp_dir}/kube-controller-manager <<-EOF 
	KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
	--v=4 \
	--master=127.0.0.1:8080 \
	--leader-elect=true \
	--address=127.0.0.1 \
	--service-cluster-ip-range=10.0.0.0/24 \ 
	--cluster-name=kubernetes \
	--cluster-signing-cert-file=${k8s_dir}/ssl/ca.pem \
	--cluster-signing-key-file=${k8s_dir}/ssl/ca-key.pem  \
	--root-ca-file=${k8s_dir}/ssl/ca.pem \
	--service-account-private-key-file=${k8s_dir}/ssl/ca-key.pem"
	EOF
}

kubelet_conf(){
	cat > ${tmp_dir}/kubelet <<-EOF
	KUBELET_OPTS="--logtostderr=true \
	--v=4 \
	--hostname-override=192.168.135.129 \
	--kubeconfig=${k8s_dir}/cfg/kubelet.kubeconfig \
	--bootstrap-kubeconfig=${k8s_dir}/cfg/bootstrap.kubeconfig \
	--config=${k8s_dir}/cfg/kubelet.config \
	--cert-dir=${k8s_dir}/ssl \
	--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
	EOF
	cat > ${tmp_dir}/kubelet.config  <<-EOF
	kind: KubeletConfiguration
	apiVersion: kubelet.config.k8s.io/v1beta1
	address: 192.168.135.129
	port: 10250
	readOnlyPort: 10255
	cgroupDriver: cgroupfs
	clusterDNS: ["10.0.0.2"]
	clusterDomain: cluster.local.
	failSwapOn: false
	authentication:
	  anonymous:
		enabled: true 
	  webhook:
		enabled: false
	EOF
}

proxy_conf(){
	cat > ${tmp_dir}/kube-proxy  <<-EOF
	KUBE_PROXY_OPTS="--logtostderr=true \
	--v=4 \
	--hostname-override=192.168.135.129 \
	--cluster-cidr=10.0.0.0/24 \
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
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${k8s_dir}/{bin,cfg,ssl}"
			scp  -P ${ssh_port[i]} ${tmp_dir}/kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubectl} root@${host}:${k8s_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/{ca.pem,ca-key.pem,kubernetes.pem,kubernetes-key.pem,kube-controller-manager.pem,kube-controller-manager-key.pem,kube-scheduler.pem,kube-scheduler-key.pem}  root@${host}:${k8s_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/{kube-apiserver,kube-scheduler,kube-controller-manager}  root@${host}:${k8s_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/apiserver_init root@${host}:/etc/systemd/system/kube-apiserver.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/scheduler_init root@${host}:/etc/systemd/system/kube-scheduler.service
			scp  -P ${ssh_port[i]} ${tmp_dir}/controller_init root@${host}:/etc/systemd/system/kube-controller-manager.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload"
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
			scp  -P ${ssh_port[i]} ${tmp_dir}/kubernetes/server/bin/{kube-proxy,kubelet} root@${host}:${k8s_dir}/bin
			scp  -P ${ssh_port[i]} ${tmp_dir}/{ca.pem,ca-key.pem,kube-proxy.pem,kube-proxy-key.pem}  root@${host}:${k8s_dir}/ssl
			scp  -P ${ssh_port[i]} ${tmp_dir}/{kube-proxy,kubelet}  root@${host}:${k8s_dir}/cfg
			scp  -P ${ssh_port[i]} ${tmp_dir}/proxy_init root@${host}:/etc/systemd/system/kube-proxy.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl daemon-reload"

		fi
		((i++))
	done
	

}

create_token(){
	cat > ${k8s_dir}/cfg/token.csv <<-EOF
	674c457d4dcf2eefe4920d7dbb6b0ddc,kubelet-bootstrap,10001,"system:kubelet-bootstrap"
	EOF

}

k8s_bin_install(){
	env_load
	install_cfssl
	create_etcd_ca
	down_k8s_file
	add_system
	etcd_install_ctl
	flannel_install_ctl
	master_install_ctl
	node_install_ctl
}
