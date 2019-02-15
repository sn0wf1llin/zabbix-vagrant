#! /bin/bash




DATABASE_NAME="zabbix"

function debug() {
	echo "set number" > ~/.vimrc
	echo "syntax on" >> ~/.vimrc

}


function imain(){
	debug 

	yum install -y lsof net-tools mariadb mariadb-server 1> /dev/null
	/usr/bin/mysql_install_db --user=mysql

	systemctl start mariadb ; systemctl enable mariadb

	# check if db exists
	if [ ! -d /var/lib/mysql/"$DATABASE_NAME" ]; then
		mysql -uroot -e "create database $DATABASE_NAME character set utf8 collate utf8_bin ; GRANT ALL PRIVILEGES ON $DATABASE_NAME.* to $ZABBIX_USER@localhost identified by '$ZABBIX_PASSWORD';"

	fi;
	
	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm 1> /dev/null
	yum install -y zabbix-server-mysql zabbix-web-mysql 1> /dev/null

	zcat /usr/share/doc/zabbix-server-mysql-*/create.sql.gz | mysql -u"$ZABBIX_USER" -p"$ZABBIX_PASSWORD" $DATABASE_NAME

	ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"

	# change server configuration
	sed -i -E '/DBHost/s/^# //g; /DBPassword/s/^#{1,2} //; s/DBPassword=.*/DBPassword='$ZABBIX_PASSWORD'/' $ZABBIX_CONF
	# check changes
	cat $ZABBIX_CONF | grep -iE 'dbhost|dbname|dbuser|dbpassword'

	systemctl start zabbix-server || echo "zabbix_server start [ failed ]" ; systemctl enable zabbix-server

	PHP_CONF="/etc/httpd/conf.d/zabbix.conf"
	# change web
	sed -i '/date.timezone/s/# //g; /date.timezone/s/date.timezone.*/date.timezone Europe\/Minsk/' $PHP_CONF;
	# check changes
	cat $PHP_CONF | grep timezone

	systemctl start firewalld
	firewall-cmd --permanent --add-port=10051/tcp
	firewall-cmd --reload

	systemctl start httpd || echo "httpd start [ failed ]"
	
	lsof -i -P -n | grep -E '10051|10050' || echo "no ports LISTEN"
}


function mkagent() {
	unset ZABBIX_USER ZABBIX_PASSWORD

	export ZABBIX_USER="zabbix"
	export ZABBIX_PASSWORD="agentpassword"

	imain

}

function mkserver() {
	unset ZABBIX_USER ZABBIX_PASSWORD

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