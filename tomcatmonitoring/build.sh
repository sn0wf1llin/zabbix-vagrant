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
	yum install -y lsof telnet net-tools

	echo "set number" > ~/.vimrc
	echo "syntax on" >> ~/.vimrc
}

function install_tomcat() {
	yum install -y java-1.8.0-openjdk-devel 1> /dev/null
	yum install -y tomcat tomcat-webapps tomcat-admin-webapps 

	firewall-cmd --add-port=8080/tcp --permanent
	firewall-cmd --reload

	# copy .war for deployment 
	cp /vagrant/JavaHelloWorldApp.war /usr/share/tomcat/webapps/

	TOMCAT_CONFIG_FILE="/etc/sysconfig/tomcat"
	cat $TOMCAT_CONFIG_FILE | grep preferIPv4Stack || echo 'JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Xmx512m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC"' >> $TOMCAT_CONFIG_FILE;

	systemctl start tomcat; systemctl enable tomcat;
	curl -IL http://localhost:8080/JavaHelloWorldApp
}

function mkagent() {
	debug 
	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm 1> /dev/null
	yum install -y zabbix-agent zabbix-sender  1> /dev/null

	ZABBIX_CONF="/etc/zabbix/zabbix_agentd.conf"
	sed -i '/DebugLevel=/s/# //g' $ZABBIX_CONF

	ZABBIX_SERVER_IP="$2";
	if [ -z $ZABBIX_SERVER_IP ]; then
		echo "server ip error: not defined, <$2> instead. exit."
		exit 1;
	fi;

	case "$1" in 
		active)
			ZABBIX_SERVER_PORT="10051"

			# uncomment HostnameItem
			sed -i -E '/HostnameItem/s/^# //g' $ZABBIX_CONF

			# replace ServerActive with ZABBIX_SERVER_IP
			sed -i "s/^ServerActive.*/ServerActive=$ZABBIX_SERVER_IP/" $ZABBIX_CONF
			
			#check config
			cat $ZABBIX_CONF | grep -i -E '{serveractive|hostnameitem}'
			# set ServerPort
			#cat $ZABBIX_CONF | grep -i serverport || echo "ServerPort=$ZABBIX_SERVER_PORT" >> $ZABBIX_CONF
			;;
		passive)
			# uncomment ListenIP
			#sed -i '/ListenIP/s/^# //g' $ZABBIX_CONF

			# uncomment HostnameItem
			# sed -i -E '/Hostname/s/Hostname=Host1111//g' $ZABBIX_CONF

			# uncomment StartAgents
			sed -i '/^# StartAgents=/s/^# //' $ZABBIX_CONF
		
			# add ZABBIX_SERVER_IP to Server tag
			sed -i "s/^Server=127.0.0.1.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_CONF
			# replace ServerActive with ZABBIX_SERVER_IP
			sed -i "s/^ServerActive.*/ServerActive=$ZABBIX_SERVER_IP/" $ZABBIX_CONF
			
			# replace ListenPort
			# sed -i "/ListenPort=/s/^# //; s/ListenPort=.*/ListenPort=10050/" $ZABBIX_CONF

			#check config
			cat $ZABBIX_CONF | grep -i -E '{server=|listenip|ListenPort|startagents}'
			;;

		*)
			echo "agent type error: not <active> or <passive>, $1 instead. exit."
			exit 1;
			;;
	esac

	systemctl start firewalld ; systemctl enable firewalld
	firewall-cmd --add-service={http,https} --permanent
	firewall-cmd --add-port={10051/tcp,10050/tcp} --permanent
	# firewall-cmd --add-port=10050/tcp --permanent
	firewall-cmd --reload

	systemctl start zabbix-agent && systemctl enable zabbix-agent || echo "zabbix-agent start [ failed ]" ;
	
	lsof -i -P -n | grep ":10050" | tail -n 5 || echo "no ports LISTEN"

	install_tomcat

}

function mkserver() {
	yum install -y lsof net-tools mariadb mariadb-server zabbix-get 1> /dev/null
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
		# build.sh agent active 192.168.33.10
		# build.sh agent 192.168.33.10

		unset ZABBIX_USER ZABBIX_PASSWORD
		export ZABBIX_USER="zabbix"
		export ZABBIX_PASSWORD="agentpassword"
		
		if [ "$#" -eq 2 ]; then
			AGENT_STATE=$DEFAULT_AGENT_STATE
			ZABBIX_SERVER_IP="$2"

		elif [ "$#" -eq 3 ]; then
			AGENT_STATE="$2"
			ZABBIX_SERVER_IP="$3"
		else
			echo "Usage: ./build.sh agent ZABBIX_SERVER_IP or ./build.sh agent <active>/<passive> ZABBIX_SERVER_IP;"
			exit 1;
		fi;

		mkagent $AGENT_STATE $ZABBIX_SERVER_IP
		
		trap failed 1
		trap success 0
		;;
	server)
		unset ZABBIX_USER ZABBIX_PASSWORD

		export ZABBIX_USER="zabbix"
		export ZABBIX_PASSWORD="serverpassword"

		debug 
		mkserver 

		trap failed 1
		trap success 0
		;;
	*)
		echo "<server> or <agent> type required; exit ;"
		exit 1;
		;;
esac
