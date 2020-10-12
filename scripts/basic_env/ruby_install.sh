#!/bin/bash

ruby_env_load(){
	tmp_dir=/tmp/ruby_tmp
	soft_name=ruby
	program_version=('2.3' '2.4')
	url="http://cache.ruby-china.com/pub/ruby/"
	select_version
	install_dir_set
	online_version
	down_url="${url}/ruby-${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/ruby-${detail_version_number}.tar.gz ${tmp_dir}

}


ruby_install(){

	yum install -y zlib-devel openssl-devel
	cd ${tar_dir}
	./configure --prefix=${home_dir}  --disable-install-rdoc
	make && make install
	add_sys_env "PATH=${home_dir}/bin:\$PATH"

	gem sources --add http://gems.ruby-china.com/ --remove http://rubygems.org/
	ruby -v
	if [ $? = 0 ];then
		info_log "ruby环境搭建成功."
	else
		error_log "ruby环境搭建失败."
		exit 1
	fi
}

ruby_install_ctl(){
	ruby_env_load
	ruby_install
	clear_install
}