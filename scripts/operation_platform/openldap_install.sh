#!/bin/bash

openldap_env_load(){
	tmp_dir=/usr/local/src/openldap_tmp
	soft_name=openldap

}

openldap_set(){
	input_option "输入ldap管理员密码" "123456" "ldap_pw"
	ldap_pw=${input_value}
	input_option "输入ldap DC(Domain Component)" "alibaba" "dc"
	dc=${input_value}

}

openldap_install(){

	yum install -y openldap openldap-clients openldap-servers
	service_control slapd.service y
	mkdir -p ${tmp_dir}

}

openldap_config(){

	cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	chown ldap.ldap /var/lib/ldap/DB_CONFIG
	ldap_pw_encrypt=`slappasswd -s ${ldap_pw}`
	#新增修改密码文件
	cp ${workdir}/config/openldap/chrootpw.ldif ${tmp_dir}
	cp ${workdir}/config/openldap/domain-dbadmin.ldif ${tmp_dir}
	cp ${workdir}/config/openldap/basedomain.ldif ${tmp_dir}
	
	sed -i "s/olcRootPW:.*/olcRootPW: ${ldap_pw_encrypt}/" ${tmp_dir}/chrootpw.ldif
	sed -i "s/olcRootPW:.*/olcRootPW: ${ldap_pw_encrypt}/" ${tmp_dir}/domain-dbadmin.ldif
	sed -i "s/alibaba/${dc}/" ${tmp_dir}/domain-dbadmin.ldif
	sed -i "s/alibaba/${dc}/" ${tmp_dir}/basedomain.ldif
	
	# 执行命令，修改ldap配置，通过-f执行文件
	ldapadd -Y EXTERNAL -H ldapi:/// -f ${tmp_dir}/chrootpw.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f ${tmp_dir}/domain-dbadmin.ldif
	ldapadd -x -D cn=admin,dc=${dc},dc=com -f ${tmp_dir}/basedomain.ldif
	#添加几个基础的 Schema
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
}

openldap_install_ctl(){
	openldap_env_load
	openldap_set
	openldap_install
	openldap_config
}