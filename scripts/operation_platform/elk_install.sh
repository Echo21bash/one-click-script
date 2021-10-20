#!/bin/bash
set -e

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${elk_module[@]} =~ 'elasticsearch' ]];then
		elasticsearch_install_ctl
	fi
	if [[ ${elk_module[@]} =~ 'logstash' ]];then
		logstash_install_ctl
	fi
	if [[ ${elk_module[@]} =~ 'kibana' ]];then
		kibana_install_ctl
	fi
	if [[ ${elk_module[@]} =~ 'filebeat' ]];then
		filebeat_install_ctl
	fi
}
