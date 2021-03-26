#!/bin/bash

node_env_load(){
	tmp_dir=/tmp/node_tmp
	soft_name=node
	program_version=('10' '11' '12')
	url="http://mirrors.ustc.edu.cn/node"
	url="http://npm.taobao.org/mirrors/node"	
	select_version
	install_dir_set
	online_version
	down_url="${url}/v${detail_version_number}/node-v${detail_version_number}-linux-x64.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/${down_file_name} ${tmp_dir}
}

node_install(){
	home_dir=${install_dir}/node
	mkdir -p ${home_dir}
	cp -rp ${tar_dir}/* ${home_dir}
	add_sys_env "NODE_HOME=${home_dir} PATH=\${NODE_HOME}/bin:\$PATH"
	${home_dir}/bin/npm config set registry https://registry.npm.taobao.org
}

node_install_ctl(){
	node_env_load
	node_install
	clear_install

}
