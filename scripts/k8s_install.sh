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
		if [[ ${host} = "${etcd_ip[$j]}" ]];then
			scp  -P ${ssh_port[i]} ${tmp_dir}/etcd-v3.2.30-linux-arm64.tar.gz root@${host}:/tmp
			((j++))
		fi
		((i++))
	done

}


etcd_conf(){

	etcd_num=${#etcd_ip[*]}
	if [[ ${etcd_num} = '1' ]];then
		local i=0
		for host in ${host_name[@]};
		do
			if [[ ${host} = "${etcd_ip}" ]];then
				send_file
				ssh ${host_name[$i]} -p ${ssh_port[$i]} "${workdir}/scripts/k8s_etcd.sh"
				
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
				ssh ${host_name[$i]} -p ${ssh_port[$i]} "${workdir}/scripts/k8s_etcd.sh"
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
