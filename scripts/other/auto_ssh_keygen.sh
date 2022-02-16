#!/bin/bash

auto_ssh_keygen_tool(){
	vi ${workdir}/config/ssh/passwd.txt
	while read str
	do
		a=(${str})
		host_ip=${a[0]}
		ssh_port=${a[1]}
		passwd=${a[2]}
		auto_ssh_keygen
	done < ${workdir}/config/ssh/passwd.txt
}
