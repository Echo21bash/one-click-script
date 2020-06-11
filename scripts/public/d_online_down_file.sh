#!/bin/bash
online_down_file(){
	[[ ! -d ${tmp_dir} ]] && mkdir -p ${tmp_dir}
	down_file ${down_url} ${tmp_dir}

}