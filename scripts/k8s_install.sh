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
			scp  -P ${ssh_port[i]} ${tmp_dir}/init root@${host}:/etc/systemd/system/etcd.service
			ssh ${host_name[$i]} -p ${ssh_port[$i]} "
			mkdir -p ${etcd_dir}/{bin,cfg,ssl}
			cd /tmp
			tar zxvf etcd-v3.2.30-linux-amd64.tar.gz
			\cp etcd-v3.2.30-linux-amd64/{etcd,etcdctl} ${etcd_dir}/bin/
			\cp ca*pem etcd*pem ${etcd_dir}/ssl
			\cp etcd.yml ${etcd_dir}/cfg
			rm -rf etcd-v3.2.30-linux-amd64.tar.gz etcd-v3.2.30-linux-amd64"
			
			((j++))
		fi
		((i++))
	done
}

get_etcd_cluster_ip(){

	etcd_num=${#etcd_ip[*]}
	local i=0
	for ((i=1;i<${etcd_num};i++));
	do
		etcd_cluster_ip=${etcd_cluster_ip}etcd-$i=https://${etcd_ip[$i]}:2380,

	done
}

add_system(){
	home_dir=${tmp_dir}
	Type="notify"
	ExecStart="${etcd_dir}/bin/etcd --config-file=${etcd_dir}/cfg/etcd.yml"
	conf_system_service
	
}

k8s_bin_install(){
	env_load
	install_cfssl
	create_etcd_ca
	down_k8s_file
	etcd_install_ctl
}
