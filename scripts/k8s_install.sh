#!/bin/bash

env_load(){
	. ${workdir}/config/k8s/k8s.conf
	auto_ssh_keygen
	tmp_dir=/tmp/install_tmp
	mkdir -p ${tmp_dir}
	cd ${tmp_dir}
}

install_cfssl(){
	down_file https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 /usr/local/bin/cfssl
	down_file https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 /usr/local/bin/cfssljson
	down_file https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
	chmod +x /usr/local/bin/cfssl*

}

create_etcd_ca(){
	
	cfssl gencert -initca ${workdir}/config/k8s/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=www ${workdir}/config/k8s/etcd-csr.json | cfssljson -bare etcd
	
}

down_k8s_file(){
	down_file https://mirrors.huaweicloud.com/etcd/v3.2.30/etcd-v3.2.30-linux-amd64.tar.gz ${tmp_dir}/etcd-v3.2.30-linux-amd64.tar.gz
	down_file https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz ${tmp_dir}/flannel-v0.10.0-linux-amd64.tar.gz

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
		listen-peer-urls: "https://${etcd_ip[$j]}:2380"
		listen-client-urls: "https://${etcd_ip[$j]}:2379"
		#[Clustering]
		initial-advertise-peer-urls: "https://${etcd_ip[$j]}:2380"
		advertise-client-urls: "https://${etcd_ip[$j]}:2379"
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
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${etcd_ip[$j]}" ]];then
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			systemctl restart etcd.service"
			((j++))
		fi
		((i++))
	done
	unhealthy
}

etcd_check(){
	local i=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${etcd_ip}" ]];then
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
		etcd_endpoints=https://${etcd_ip[$i]}:2379,
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
	EnvironmentFile="${flannel_dir}/cfg/flanneld"
	ExecStart="${flannel_dir}/bin/flanneld --ip-masq \$FLANNEL_OPTIONS"
	ExecStartPost="${flannel_dir}/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker"
	conf_system_service
	
}

etcd_install_ctl(){
	get_etcd_cluster_ip
	add_system
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${etcd_ip[$j]}" ]];then
			etcd_conf
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd-v3.2.30-linux-amd64.tar.gz root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/ca.pem  root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/ca-key.pem  root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd.pem  root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd-key.pem  root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd.yml  root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd_init root@${host}:/etc/systemd/system/etcd.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${etcd_dir}/{bin,cfg,ssl}
			mkdir -p ${etcd_data_dir}
			cd /tmp
			tar zxvf etcd-v3.2.30-linux-amd64.tar.gz
			\cp etcd-v3.2.30-linux-amd64/{etcd,etcdctl} ${etcd_dir}/bin/
			\cp ca*pem etcd*pem ${etcd_dir}/ssl
			\cp etcd.yml ${etcd_dir}/cfg
			rm -rf etcd-v3.2.30-linux-amd64.tar.gz etcd-v3.2.30-linux-amd64
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
	FLANNEL_OPTIONS="--etcd-endpoints=${etcd_endpoints} -etcd-cafile=${etcd_dir}/ssl/ca.pem -etcd-certfile=${etcd_dir}/ssl/etcd.pem -etcd-keyfile=${etcd_dir}/ssl/etcd-key.pem"
	EOF
}

flannel_install_ctl(){
	
	add_system
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = "${node_ip[$j]}" ]];then
			docker_install
			flannel_conf

			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel-v0.10.0-linux-amd64.tar.gz root@${host}:/tmp
	
			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel root@${host}:/tmp
			scp  -P ${ssh_port[i]} ${tmp_dir}/flannel_init root@${host}:/etc/systemd/system/flanneld.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${flannel_dir}/{bin,cfg,ssl}
			mkdir -p ${etcd_data_dir}
			cd /tmp
			tar zxvf flannel-v0.10.0-linux-amd64.tar.gz
			\cp {flanneld,mk-docker-opts.sh} ${flannel_dir}/bin/
			\cp ca*pem etcd*pem ${etcd_dir}/ssl
			\cp flannel ${flannel_dir}/cfg
			rm -rf flannel-v0.10.0-linux-amd64.tar.gz
			systemctl daemon-reload"
			
			((j++))
		fi
		((i++))
	done

}

k8s_bin_install(){
	env_load
	install_cfssl
	create_etcd_ca
	down_k8s_file
	etcd_install_ctl
	flannel_install_ctl
}
