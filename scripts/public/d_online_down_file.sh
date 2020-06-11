#!/bin/bash
online_down(){
	[[ ! -d ${tmp_dir} ]] && mkdir -p ${tmp_dir}
	down_file ${down_url} ${tmp_dir}

}