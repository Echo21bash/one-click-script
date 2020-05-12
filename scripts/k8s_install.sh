#!/bin/bash
install_cfssl(){
	down_file https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 /usr/local/bin/cfssl
	down_file https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 /usr/local/bin/cfssljson
	down_file https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
	chmod +x /usr/local/bin/cfssl*

}

create_etcd_ca(){
	mkdir -p ${etcd_dir}/{bin,cfg,ssl}
	cfssl gencert -initca ${workdir}/config/k8s/ca-csr.json | cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=${workdir}/config/k8s/ca-config.json -profile=www ${workdir}/config/k8s/etcd-csr.json | cfssljson -bare etcd
	cp ca*pem etcd*pem ${etcd_dir}/ssl
}

install_etcd(){
	down_file https://mirrors.huaweicloud.com/etcd/v3.2.30/etcd-v3.2.30-linux-arm64.tar.gz ${etcd_dir}/etcd-v3.2.30-linux-arm64.tar.gz
	cd ${etcd_dir}
	tar zxvf etcd-v3.2.12-linux-amd64.tar.gz
	mv ${etcd_dir}/etcd-v3.2.30-linux-arm64/{etcd,etcdctl} ${etcd_dir}/bin/

}

etcd_conf(){
	if [[ ${etcd_num} = '1' ]];then
		local i=0
		for host in ${host_name[@]};
		do
			if [[ ${host} = '${etcd_ip}' ]];then
				ssh ${host_name[$i]} -p ${ssh_port[$i]}
		
				cat >>${etcd_dir}/cfg/etcd <-EOF  
				#[Member]
				ETCD_NAME="etcd"
				ETCD_DATA_DIR="${etcd_data_dir}"
				ETCD_LISTEN_PEER_URLS="https://${etcd_ip}:2380"
				ETCD_LISTEN_CLIENT_URLS="https://${etcd_ip}:2379"
				EOF
			fi
		done
	fi

	if [[ ${etcd_num} != '1' ]];then
		get_etcd_cluster_ip
		local j=1
		local i=0
		
		for ((j=1;j<=${etcd_num};j++));
		do
			ssh ${host_name[$i]} -p ${ssh_port[$i]}
			cat >>${etcd_dir}/cfg/etcd <-EOF  
			#[Member]
			ETCD_NAME="etcd-$j"
			ETCD_DATA_DIR="${etcd_data_dir}"
			ETCD_LISTEN_PEER_URLS="https://${etcd_ip[$i]}:2380"
			ETCD_LISTEN_CLIENT_URLS="https://${etcd_ip[$i]}:2379"
			#[Clustering]
			ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${etcd_ip[$i]}:2380"
			ETCD_ADVERTISE_CLIENT_URLS="https://${etcd_ip[$i]}:2379"
			ETCD_INITIAL_CLUSTER="${etcd_cluster_ip}"
			ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
			ETCD_INITIAL_CLUSTER_STATE="new"
			EOF
			((i++))
		done
	fi
}



get_etcd_cluster_ip(){

	local j=1
	local i=0
  
	for ((j=1;j<=${etcd_num};j++));
	do
		etcd_cluster_ip=${etcd_cluster_ip}etcd-$j=https://${etcd_ip[$i]}:2380,
		((i++))
	done
}






