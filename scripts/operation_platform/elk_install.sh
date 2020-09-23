#!/bin/bash

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${output_value[@]} =~ 'elasticsearch' ]];then
		elasticsearch_install_ctl
	elif [[ ${output_value[@]} =~ 'logstash' ]];then
		logstash_install_ctl
	elif [[ ${output_value[@]} =~ 'kibana' ]];then
		kibana_install_ctl
	elif [[ ${output_value[@]} =~ 'filebeat' ]];then
		filebeat_install_ctl
	fi	
}
