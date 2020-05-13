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
	down_file https://mirrors.huaweicloud.com/etcd/v3.2.30/etcd-v3.2.30-linux-arm64.tar.gz ${tmp_dir}/etcd-v3.2.30-linux-arm64.tar.gz
}

send_file(){
	local i=0
	local j=0
	for host in ${host_name[@]};
	do
		if [[ ${host} = '${etcd_ip[$j]}' ]];then
			scp ${tmp_dir}/etcd-v3.2.30-linux-arm64.tar.gz root@${host}:/tmp -P ${ssh_port[i]}
			((j++))
		fi
		((i++))
	done

}
install_etcd(){
	
	mkdir -p ${etcd_dir}/{bin,cfg,ssl}
	cd /tmp
	tar zxvf etcd-v3.2.12-linux-amd64.tar.gz
	mv etcd-v3.2.30-linux-arm64/{etcd,etcdctl} ${etcd_dir}/bin/
	rm -rf etcd-v3.2.12-linux-amd64.tar.gz etcd-v3.2.30-linux-arm64
	
}

etcd_conf(){

	etcd_num=${#etcd_ip[*]}
	if [[ ${etcd_num} = '1' ]];then
		local i=0
		for host in ${host_name[@]};
		do
			if [[ ${host} = "${etcd_ip}" ]];then
				send_file
				install_etcd
				add_system
				ssh ${host_name[$i]} -p ${ssh_port[$i]}
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
				exit
			fi
		done
	fi

	if [[ ${etcd_num} > '1' ]];then
		get_etcd_cluster_ip
		local i=0
		local j=0
		for host in ${host_name[@]};
		do
			if [[ ${host} = "${etcd_ip[$j]}" ]];then
				send_file
				install_etcd
				add_system
				ssh ${host_name[$i]} -p ${ssh_port[$i]}
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
				exit
				((j++))
			fi
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

add_system(){
	home_dir=${etcd_dir}
	Type="notify"
	ExecStart="${home_dir}/bin/etcd --config-file=${home_dir}/cfg/etcd.conf"
	conf_system_service
	add_system_service etcd ${home_dir}/init

}

k8s_bin_install(){
	env_load
	install_cfssl
	create_etcd_ca
	down_k8s_file
	
	etcd_conf
	

}
