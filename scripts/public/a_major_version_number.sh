#!/bin/bash
select_version(){

	output_option "请选择${soft_name}版本" "${program_version[*]}" "version_number"
	version_number=${output_value}
}