#!/bin/bash
set -e

vpn_install_ctl(){
	
	output_option "选择安装的VPN类型" "sslvpn wireguard" "vpn_type"

	vpn_type=${output_value[@]}
	if [[ ${output_value[@]} =~ 'sslvpn' ]];then
		anylink_install_ctl
	elif [[ ${output_value[@]} =~ 'wireguard' ]];then
		wireguard_install_ctl
	fi	
}
