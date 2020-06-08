#!/bin/bash

node_env_load(){
	tmp_dir=/tmp/node_tmp
	soft_name=node
	program_version=('9' '10')
}
node_install(){

	cp -rp ${tar_dir}/* ${home_dir}
	add_sys_env "NODE_HOME=${home_dir} PATH=\${NODE_HOME}/bin:\$PATH"
	${home_dir}/bin/npm config set registry https://registry.npm.taobao.org
}

node_install_ctl(){
	node_env_load
	install_set
	node_install_clear

}
