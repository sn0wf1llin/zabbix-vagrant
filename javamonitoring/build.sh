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
	yum install -y lsof telnet net-tools vim

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
	cat $TOMCAT_CONFIG_FILE | grep preferIPv4Stack || echo 'JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Xmx512m -XX:MaxPermSize=256m -XX:+UseConcMarkSweepGC -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=12345 -Dcom.sun.management.jmxremote.rmi.port=12346 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"' >> $TOMCAT_CONFIG_FILE;

	systemctl start tomcat; systemctl enable tomcat;
	curl -IL http://localhost:8080/JavaHelloWorldApp
}

function mkagent() {
	debug 
	yum install -y https://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm
	yum install -y zabbix-agent # 1> /dev/null

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

	# configure jmx/jri listener 
	CATALINA_HOME="/usr/share/tomcat"
	wget  http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.8/bin/extras/catalina-jmx-remote.jar -P /tmp/
	mv /tmp/catalina-jmx-remote.jar $CATALINA_HOME/lib/
	new_listener='<Listener className="org.apache.catalina.mbeans.JmxRemoteLifecycleListener" rmiRegistryPortPlatform="8097" rmiServerPortPlaform="8098" />'
	cat $CATALINA_HOME/conf/server.xml | grep rmiRegistry || sed -i "/port=\"8005\"/a\\$new_listener" $CATALINA_HOME/conf/server.xml

	firewall-cmd --add-port={12345/tcp,12346/tcp,8097/tcp,8098/tcp} --permanent
	firewall-cmd --reload
	systemctl restart zabbix-agent

}


function server_install_configure_java_gw() {
	# install java gateway
	yum install -y zabbix-java-gateway

	systemctl start zabbix-java-gateway; systemctl enable zabbix-java-gateway; 

	ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
	SERVER_IP="$1"
	sed -i "/JavaGateway=/s/^# //; /JavaGateway=/s/=.*/=$SERVER_IP/" $ZABBIX_CONF
	sed -i "/JavaGatewayPort=/s/^# //" $ZABBIX_CONF
	sed -i "/StartJavaPollers=/s/^# //; /StartJavaPollers=/s/=.*/=5/" $ZABBIX_CONF
	
	systemctl restart zabbix-server
}

function mkserver() {
	debug
	yum install -y mariadb mariadb-server zabbix-get 1> /dev/null
	/usr/bin/mysql_install_db --user=mysql

	systemctl start mariadb && systemctl enable mariadb || echo "mariadb start [ failed ]" ;

	# check if db exists
	if [ ! -d /var/lib/mysql/"$DATABASE_NAME" ]; then
		mysql -uroot -e "create database $DATABASE_NAME character set utf8 collate utf8_bin ; GRANT ALL PRIVILEGES ON $DATABASE_NAME.* to $ZABBIX_USER@localhost identified by '$ZABBIX_PASSWORD';"

	fi;
	
	yum install -y http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-1.el7.centos.noarch.rpm 1> /dev/null
	yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent 
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

	systemctl status zabbix-server
	SERVER_IP="$1"
	server_install_configure_java_gw $SERVER_IP
	systemctl status zabbix-server
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

		if [ "$#" -eq 2 ]; then
			ZABBIX_SERVER_IP="$2"; 
			mkserver $ZABBIX_SERVER_IP;

		else
			mkserver
		fi;

		trap failed 1
		trap success 0
		;;
	*)
		echo "<server> or <agent> type required; exit ;"
		exit 1;
		;;
esac
