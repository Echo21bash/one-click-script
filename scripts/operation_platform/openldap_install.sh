#!/bin/bash

openldap_set(){
	input_option "输入ldap管理员密码" "123456" "ldap_pw"
	ldap_pw=${input_value}
	input_option "输入ldap DC(Domain Component)" "alibaba" "dc"
	dc=${input_value}

}

openldap_install(){

	yum install -y openldap openldap-clients openldap-servers
	service_control slapd.service y

}

openldap_config(){

	cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	chown ldap.ldap /var/lib/ldap/DB_CONFIG
	ldap_pw_encrypt=`slappasswd -s ${ldap_pw}`
	#新增修改密码文件
	mkdir -p /tmp/openldap/
	cp ${workdir}/config/openldap/chrootpw.ldif /tmp/openldap/
	cp ${workdir}/config/openldap/domain-dbadmin.ldif /tmp/openldap/
	cp ${workdir}/config/openldap/admin.ldif /tmp/openldap/
	
	sed -i /olcRootPW:.*/olcRootPW: ${ldap_pw_encrypt}/tmp/openldap/chrootpw.ldif
	sed -i /olcRootPW:.*/olcRootPW: ${ldap_pw_encrypt}/tmp/openldap/domain-dbadmin.ldif
	sed -i /alibaba/${dc}/tmp/openldap/domain-dbadmin.ldif
	sed -i /alibaba/${dc}/tmp/openldap/admin.ldif
	
	# 执行命令，修改ldap配置，通过-f执行文件
	ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/openldap/chrootpw.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/openldap/basedomain.ldif
	info_log "请输入设置的ldap密码"
	ldapadd -x -D cn=admin,dc=${dc},dc=com -f /tmp/openldap/admin.ldif
	#添加几个基础的 Schema
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
}

openldap_install_ctl(){
	openldap_set
	openldap_install
	openldap_config
}