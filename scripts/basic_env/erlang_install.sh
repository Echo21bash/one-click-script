#!/bin/bash

erlang_env_load(){
	tmp_dir=/usr/local/src/erlang_tmp
	soft_name=erlang
	program_version=('20' '21' '22')
	url="http://distfiles.macports.org/erlang"
	select_version
	online_version

}

erlang_down(){

	down_url="${url}/otp_src_${detail_version_number}.tar.gz"
	online_down_file
	unpacking_file ${tmp_dir}/otp_src_${detail_version_number}.tar.gz ${tmp_dir}
}

erlang_install_set(){

	output_option '请选择安装模式' '本机安装 批量安装' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		install_dir_set
	elif [[ ${deploy_mode} = '2' ]];then
		install_dir_set
		vi ${workdir}/config/erlang/erlang.conf
		. ${workdir}/config/erlang/erlang.conf
	fi
	
}

erlang_install(){
	home_dir=${install_dir}/erlang
	if [[ ${deploy_mode} = '1' ]];then
		yum install -y which wget perl openssl-devel make automake autoconf ncurses-devel gcc
		erlang_compile
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
		ln -snf ${home_dir}/bin/erl /usr/bin
	fi
	if [[ ${deploy_mode} = '2' ]];then
		auto_ssh_keygen
	fi

}

erlang_compile(){
	cd ${tmp_dir}/${package_root_dir}
	./configure --prefix=${home_dir} --with-ssl --enable-threads --enable-smp-support --enable-kernel-poll --enable-hipe
	if [[ $? = '0' ]];then
		success_log '编译检查通过'
		make -j 4 && make install
		if [[ $? = '0' ]];then
			success_log '编译安装完成'
		else
			error_log '编译安装失败'
			exit 1
		fi
	else
		error_log '编译检查失败'
		exit 1
	fi

}

erlang_install_ctl(){
	erlang_env_load
	erlang_install_set
	erlang_down
	erlang_install
	
}