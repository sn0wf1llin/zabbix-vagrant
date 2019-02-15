#! /bin/bash




DATABASE_NAME="zabbix"

function imain(){
	yum install -y mariadb mariadb-server
	/usr/bin/mysql_install_db --user=mysql
	systemctl start mariadb

	# check if db exists
	if [ ! -d /var/lib/mysql/"$DATABASE_NAME" ]; then
    	mysql -e "create database $DATABASE_NAME character set utf8 collate utf8_bin; grant all privileges on $DATABASE_NAME.* to $ZABBIX_USER@localhost identified by '$ZABBIX_PASSWORD'; quit;"
	fi;
	
	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-agent-3.4.15-1.el7.x86_64.rpm 
	yum install -y zabbix-web-mysql 

}


function mkagent() {
	unset ZABBIX_USER, ZABBIX_PASSWORD
	export ZABBIX_USER="zabbix"
	export ZABBIX_PASSWORD="agentpassword"

	imain

}

function mkserver() {
	unset ZABBIX_USER, ZABBIX_PASSWORD
	export ZABBIX_USER="zabbix"
	export ZABBIX_PASSWORD="serverpassword"

	imain

}

TYPE="$1"

case $TYPE in 
	client)
		mkagent
		;;
	server)
		mkserver
		;;
	*)
		echo "<server> or <agent> type required"
		;;
esac