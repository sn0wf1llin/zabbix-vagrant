#! /bin/bash

DEFAULT_AGENT_STATE="passive"
DATABASE_NAME="zabbix"
TYPE="$1"


function failed(){
	echo "$TYPE installation failed"
}

function success(){
	echo "$TYPE installation success"
}

function debug() {
	echo "set number" > ~/.vimrc
	echo "syntax on" >> ~/.vimrc

}

function mkagent() {

	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm 1> /dev/null
	yum install -y lsof zabbix-agent 1> /dev/null

	ZABBIX_CONF="/etc/zabbix/zabbix_agentd.conf"
	sed -i '/DebugLevel/s/# //g' $ZABBIX_CONF

	case "$1" in 
		active)
			ZABBIX_SERVER_IP="$2"; 
			ZABBIX_SERVER_PORT="10051"

			# uncomment HostnameItem
			sed -i -E '/HostnameItem/s/^# //g' $ZABBIX_CONF
			
			# set ServerPort
			cat $ZABBIX_CONF | grep -i serverport || echo "ServerPort=$ZABBIX_SERVER_PORT" >> $ZABBIX_CONF

			# replace ServerActive with ZABBIX_SERVER_IP
			sed -i "s/ServerActive.*/ServerActive=$ZABBIX_SERVER_IP/" $ZABBIX_CONF
			;;
		passive)
			# replace ServerActive with ZABBIX_SERVER_IP
			sed -i "s/ServerActive.*/ServerActive=$ZABBIX_SERVER_IP/" $ZABBIX_CONF

			# uncommect ListenIP
			sed -i '/ListenIP/s/^# //g' $ZABBIX_CONF

			# uncomment StartAgents
			sed -i '/StartAgents/s/^# //g' $ZABBIX_CONF
			;;

		*)
			echo "agent type error: not <active> or <passive>, $1 instead. exit."
			exit 1;
			;;
	esac

	systemctl start firewalld ; systemctl enable firewalld
	firewall-cmd --add-service={http,https} --permanent
	firewall-cmd --add-port=10050/tcp --permanent
	firewall-cmd --reload

	systemctl restart zabbix-agent && systemctl enable zabbix-agent || echo "zabbix-agent start [ failed ]" ;
	
	lsof -i -P -n | grep ":10050" | tail -n 5 || echo "no ports LISTEN"
}

function mkserver() {
	yum install -y lsof net-tools mariadb mariadb-server 1> /dev/null
	/usr/bin/mysql_install_db --user=mysql

	systemctl start mariadb && systemctl enable mariadb || echo "mariadb start [ failed ]" ;

	# check if db exists
	if [ ! -d /var/lib/mysql/"$DATABASE_NAME" ]; then
		mysql -uroot -e "create database $DATABASE_NAME character set utf8 collate utf8_bin ; GRANT ALL PRIVILEGES ON $DATABASE_NAME.* to $ZABBIX_USER@localhost identified by '$ZABBIX_PASSWORD';"

	fi;
	
	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm 1> /dev/null
	yum install -y zabbix-get zabbix-server-mysql zabbix-web-mysql zabbix-agent 1> /dev/null

	systemctl start httpd && systemctl enable httpd || echo "httpd start [ failed ]"

	zcat /usr/share/doc/zabbix-server-mysql-*/create.sql.gz | mysql -u"$ZABBIX_USER" -p"$ZABBIX_PASSWORD" $DATABASE_NAME

	ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
	HTTPD_CONF="/etc/httpd/conf/httpd.conf"

	# change server configuration
	# start with httpd 
	sed -i 's!DocumentRoot "/var/www/html"!DocumentRoot "/usr/share/zabbix"!' $HTTPD_CONF
	# comment alias
	sed -i '/Alias \/zabbix/s/^/# /' $HTTPD_CONF

	sed -i -E '/DBHost/s/^# //g; /DBPassword/s/^#{1,2} //; s/DBPassword=.*/DBPassword='$ZABBIX_PASSWORD'/' $ZABBIX_CONF
	# check changes
	cat $ZABBIX_CONF | grep -iE 'dbhost|dbname|dbuser|dbpassword'

	systemctl start zabbix-server && systemctl enable zabbix-server || echo "zabbix_server start [ failed ]" ;

	PHP_CONF="/etc/httpd/conf.d/zabbix.conf"
	# change web
	sed -i '/date.timezone/s/# //g; /date.timezone/s/date.timezone.*/date.timezone Europe\/Minsk/' $PHP_CONF;
	# check changes
	cat $PHP_CONF | grep timezone

	systemctl start firewalld ; systemctl enable firewalld
	firewall-cmd --add-service={http,https} --permanent
	firewall-cmd --add-port={10051/tcp,10050/tcp} --permanent
	firewall-cmd --reload

	systemctl restart zabbix-server
	systemctl restart zabbix-agent
	systemctl restart httpd
	
	lsof -i -P -n | grep -E '10051|10050' | tail -n 5 || echo "no ports LISTEN"
}

case $TYPE in 
	agent)
		# build.sh agent 192.168.33.10 active
		# build.sh agent 192.168.33.10

		unset ZABBIX_USER ZABBIX_PASSWORD
		export ZABBIX_USER="zabbix"
		export ZABBIX_PASSWORD="agentpassword"
		
		ZABBIX_SERVER_IP="$2"
		if [ -z $ZABBIX_SERVER_IP ]; then
			echo "ZABBIX_SERVER_IP must be declared; exit;"
			exit 1;
		fi;

		if [ -z "$3" ]; then
			AGENT_STATE=$DEFAULT_AGENT_STATE
		fi;

		mkagent $AGENT_STATE $ZABBIX_SERVER_IP
		;;
	server)
		unset ZABBIX_USER ZABBIX_PASSWORD

		export ZABBIX_USER="zabbix"
		export ZABBIX_PASSWORD="serverpassword"

		debug 
		mkserver 
		;;
	*)
		echo "<server> or <agent> type required; exit ;"
		exit 1;
		;;
esac

trap failed 1
trap success 0