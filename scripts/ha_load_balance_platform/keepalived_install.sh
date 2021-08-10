#!/bin/bash

keepalived_env(){
	warning_log "高可用vip通过vrrp协议实现，部分云服务器禁止vrrp协议"
	tmp_dir=/usr/local/src/keepalived_tmp
	mkdir -p ${tmp_dir}

}

keepalived_install(){
	vi ${workdir}/config/keepalived/keepalived_cluster.conf
	. ${workdir}/config/keepalived/keepalived_cluster.conf
	auto_ssh_keygen
	local i=1
	for now_host in ${host_ip[@]}
	do
		info_log "正在节点${now_host}安装keepalived"
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		yum install -y keepalived
		"
		if [[ $? ! = '0' ]];then
			error_log "节点${now_host}安装keepalived失败请检查"
			exit $?
		fi
		info_log "正在获取节点${now_host}必要参数"
		net_name=`ssh ${host_ip[$i]} -p ${ssh_port[$i]} "ip a | grep ${now_host} | grep -oE 'eth[0-9a-z]{1,3}|eno[0-9a-z]{1,3}|ens[0-9a-z]{1,3}|enp[0-9a-z]{1,3}'"`
		keepalived_config
		info_log "正在向节点${now_host}分发keepalived配置文件..."
		scp -q -r -P ${ssh_port[$i]} ${tmp_dir}/keepalived.conf ${host_ip[$i]}:/etc/keepalived
		scp -q -r -P ${ssh_port[$i]} ${tmp_dir}/check_script.sh ${host_ip[$i]}:/etc/keepalived
		
		ssh ${host_ip[$i]} -p ${ssh_port[$i]} "
		chmod +x /etc/keepalived/check_script.sh
		systemctl restart keepalived
		systemctl enable keepalived
		"
		((i++))
	done
}

keepalived_config(){
	\cp ${workdir}/config/keepalived/keepalived.conf ${tmp_dir}
	\cp ${workdir}/config/keepalived/check_script.sh ${tmp_dir}
	sed -i "s/192.168.0.100/${virtual_ip}/" ${tmp_dir}/keepalived.conf
	sed -i "s/virtual_router_id 47/virtual_router_id ${virtual_router_id}/" ${tmp_dir}/keepalived.conf
	sed -i "s/interface eth0/interface ${net_name}/" ${tmp_dir}/keepalived.conf
	if [[ -n ${exe_file} ]];then
		sed -i "s/exe_file=.*/exe_file="${exe_file}"/" ${tmp_dir}/check_script.sh
	fi
	if [[ ${url_type} = 'http|https' && -n ${url_port} ]];then
		sed -i "s?http_url=.*?http_url="${url_type}://${now_host}:${url_port}"?" ${tmp_dir}/check_script.sh
	fi
	if [[ ${url_type} = 'tcp' && -n ${url_port} ]];then
		sed -i "s?tcp_url=.*?tcp_url="${now_host} ${url_port}"?" ${tmp_dir}/check_script.sh
	fi

}

keepalived_check(){
	ping -c 1 ${virtual_ip} >/dev/null 2>&1
	success_log "VIP${virtual_ip}可达"
}

keepalived_install_ctl(){
	keepalived_env
	keepalived_install
	keepalived_check

}