#!/bin/bash

	mkdir -p ${etcd_dir}/{bin,cfg,ssl}
	cd /tmp
	tar zxvf etcd-v3.2.30-linux-amd64.tar.gz
	mv etcd-v3.2.30-linux-arm64/{etcd,etcdctl} ${etcd_dir}/bin/
	rm -rf etcd-v3.2.30-linux-amd64.tar.gz etcd-v3.2.30-linux-arm64
	
if [[ ${etcd_num} = '1' ]];then
	cat >>${etcd_dir}/cfg/etcd.conf <-EOF  
	#[Member]
	name: "etcd-$j"
	data-dir: "${etcd_data_dir}"
	listen-peer-urls: "https://${etcd_ip[$i]}:2380"
	listen-client-urls: "https://${etcd_ip[$i]}:2379"
	cert-file: "${etcd_dir}/ssl/etcd.pem"
	key-file: "${etcd_dir}/ssl/etcd-key.pem"
	peer-cert-file: "${etcd_dir}/ssl/etcd.pem"
	peer-key-file: "${etcd_dir}/ssl/etcd-key.pem"
	trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	peer-trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	EOF
fi

if [[ ${etcd_num} > '1' ]];then
		cat >>${etcd_dir}/cfg/etcd.conf <-EOF  
	#[Member]
	name: "etcd-$j"
	data-dir: "${etcd_data_dir}"
	listen-peer-urls: "https://${etcd_ip[$i]}:2380"
	listen-client-urls: "https://${etcd_ip[$i]}:2379"
	#[Clustering]
	initial-advertise-peer-urls: "https://${etcd_ip[$i]}:2380"
	advertise-client-urls: "https://${etcd_ip[$i]}:2379"
	initial-cluster: "${etcd_cluster_ip}"
	initial-cluster-token: "etcd-cluster"
	initial-cluster-state: "new"
	cert-file: "${etcd_dir}/ssl/etcd.pem"
	key-file: "${etcd_dir}/ssl/etcd-key.pem"
	peer-cert-file: "${etcd_dir}/ssl/etcd.pem"
	peer-key-file: "${etcd_dir}/ssl/etcd-key.pem"
	trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	peer-trusted-ca-file: "${etcd_dir}/ssl/ca.pem"
	EOF
fi