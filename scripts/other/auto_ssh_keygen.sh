#!/bin/bash
set -e

auto_ssh_keygen_tool(){
	vi ${workdir}/config/ssh/ssh.conf
	. ${workdir}/config/ssh/ssh.conf
	auto_ssh_keygen
}
