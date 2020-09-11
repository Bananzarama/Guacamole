#! /bin/bash

####NOTES####
# For HTTPS, link domain before use
# Hardening from jshielder
# 
# ie. sudo ./guac -u 40 -r "10.128.0." -i 36 -c "guac.domain.net"
# leave tags off for defaults
# 
# Ubuntu 20.04 update still in the works
# 
#
####REQUIRED VARIALES CHANGES
#
useramount=5
regionip="10.128.0."
hoststart=2
#
# Certbot Url
# leave empty for no cert
certurl=""
#
###

# Sudo check
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

while getopts u:r:i:c:h option
do
case "${option}"
in
u)
  useramount=${OPTARG}
  echo "Userammount set to: ${OPTARG}"
  ;;
r) 
  regionip=${OPTARG} 
  echo "Region IP set to: ${OPTARG}"
  ;;
i) 
  hoststart=${OPTARG}
  echo "Starting IP set to: ${OPTARG}"
  ;;
c) 
  certurl=${OPTARG}
  echo "URL set to: ${OPTARG}"
  ;;
h | *) 
  echo "Usage: sudo ./guac.sh [OPTION]..."
  echo 'ie. sudo ./guac -u 40 -r "10.128.0." -i 36 -c "guac.baycyber.net"'
  echo " "
  echo "  -u        Set the user amount"
  echo "  -r        Set the region ip of the cloned machines"
  echo "  -i        Set the starting ip, the lowest ip of cloned machines"
  echo "  -c        Set the URL to create a secure HTTPS connection"
  echo "  -h        This Help Menu"
  echo "  Script created by @bananzarama"
  exit 0
  ;;
esac
done

# Version variables
GUACVERSION="1.2.0"
SERVER="https://downloads.apache.org/guacamole/${GUACVERSION}"
#JSERVER="https://raw.githubusercontent.com/Jsitech/JShielder/master/UbuntuServer_18.04LTS/templates"

# Log Location
LOG="/tmp/guacamole_${GUACVERSION}_build.log"
touch ${LOG}

######Initialize variable values######
# SQL server passwords
mysqlRootPwd="B8YfxDss!!!!"
guacPwd="B0urG3per!!!!"

# Guac accounts
# accounts inc up
user="user"
pass="pass"
adminuser="admin"
adminpass="SecureAdminPass!!!!"

# RDP/VNC accounts
proto="rdp"
rdpuser="RDPuser"
rdppassword="RDPpassword"
rdpport=3389

# for some weird error with multiple logins from a single user
maxcons=10

# stops whiptail
export DEBIAN_FRONTEND=noninteractive

# Debug trap
#set -euo pipefail
#trap "echo 'error: Script failed: see tail -n25 $LOG'" ERR

# shred trap
#currentscript="$0"
#function finish {
#    echo "Shredding ${currentscript}..."
#    shred -u /home/*/${currentscript}
#    echo "Done!"
#}
#trap finish EXIT

echo "Installing guacamole webserver for CyberCamp"
echo "This script will take about 10 minutes to finish" 
echo "If you have not edited the required variables, ctrl+c, and change them now!" 
echo "Script created by Ryan Garcia @bananzarama"

# Seed MySQL install values
debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlRootPwd"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlRootPwd"

# Update apt so we can search apt-cache for newest tomcat version supported & libmysql-java
echo "Updating apt..."

if [[ -n ${certurl} ]]; then
apt-get -yqq install software-properties-common &>> ${LOG}
add-apt-repository -yn ppa:certbot/certbot &>> ${LOG}
fi

#upgrade
add-apt-repository -yn universe &>> ${LOG}
apt-get update &>> ${LOG}
apt-get -yqq full-upgrade &>> ${LOG}
apt-get -yqq autoremove &>>${LOG}

#dependencies
echo "Installing Packages..."
#tools&apps
apt-get install -yqq build-essential wget tomcat9 freerdp2-dev \
default-mysql-server default-mysql-client mysql-common freerdp2-x11 \
ghostscript dpkg-dev certbot apache2 python3-certbot-apache &>> ${LOG}

#librarys
apt-get install -yqq libjpeg62-dev libpng-dev libossp-uuid-dev \
libavcodec-dev libavutil-dev libswscale-dev libpango1.0-dev libxml2-dev &>> ${LOG}

#gets odd error (unable to correct problems, you have held broken packages) 
apt-get install -yqq libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libcairo2-dev libwebp-dev libwebsockets-dev libtool-bin &>> ${LOG}

#not working in focal
apt-get -yqq install libmysql-java mysql-utilities &>> ${LOG}

#from kifarunix
apt-get -yqq install libjpeg-turbo8-dev &>> ${LOG}

echo "Downloading Guacamole..."
#downloads
downguac(){
	sumcheck=true
	wget -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war &>> ${LOG}
	wget -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz &>> ${LOG}
	wget -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz &>> ${LOG}
	sha256sum guacamole-${GUACVERSION}.war | awk '{print $1;}' > war1.sha256
	sha256sum guacamole-server-${GUACVERSION}.tar.gz | awk '{print $1;}' > server1.sha256
	sha256sum guacamole-auth-jdbc-${GUACVERSION}.tar.gz | awk '{print $1;}' > auth1.sha256
	curl -s ${SERVER}/binary/guacamole-${GUACVERSION}.war.sha256 | awk '{print $1;}' > war2.sha256
	curl -s ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz.sha256 | awk '{print $1;}' > server2.sha256 
	curl -s ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz.sha256 | awk '{print $1;}' > auth2.sha256
	
	if [[ $(diff war1.sha256 war2.sha256) ]]; then 
	    echo "Checksum Failed..."
		sumcheck=false
	fi
	if [[ $(diff server1.sha256 server2.sha256) ]]; then 
		echo "Checksum Failed..."
		sumcheck=false
	fi
	if [[ $(diff auth1.sha256 auth2.sha256) ]]; then 
		echo "Checksum Failed..."
		sumcheck=false
	fi
	if [ ${sumcheck} = true ]; then
    echo "Checksum Success..."
    rm *.sha256
		else
    echo "Checksum Restarting..."
    rm *.war *.tar.gz *.sha256
    downguac
fi
}
downguac

# the rest
tar -xzf guacamole-server-${GUACVERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz

#make server
echo -e "Creating Server..."
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions
cd guacamole-server-${GUACVERSION}
./configure --with-init-dir=/etc/init.d &>> ${LOG}
make &>> ${LOG}
make install &>> ${LOG}
ldconfig
systemctl enable guacd &>> ${LOG}
cd ..

#install client
echo -e "Installing Webapp..."
mv guacamole-${GUACVERSION}.war /etc/guacamole/guacamole.war
mv guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/
if [[ -h /var/lib/tomcat9/webapps/guacamole.war ]]; then
    rm /var/lib/tomcat9/webapps/guacamole.war
fi
if [[ -h /etc/guacamole/lib/mysql-connector-java.jar ]]; then
    rm /etc/guacamole/lib/mysql-connector-java.jar
fi
ln -s /etc/guacamole/guacamole.war /var/lib/tomcat9/webapps/
ln -s /usr/share/java/mysql-connector-java.jar /etc/guacamole/lib/

#Tomcat splashpage
echo -e "Configuring Apache..."
echo '<iframe src="/guacamole/#/" style="height:99%;width:100%;"></iframe>' > /var/lib/tomcat9/webapps/ROOT/index.html

a2enmod proxy &>> ${LOG}
a2enmod proxy_http &>> ${LOG}
a2enmod proxy_ajp &>> ${LOG}
a2enmod rewrite &>> ${LOG}
a2enmod deflate &>> ${LOG}
a2enmod headers &>> ${LOG}
a2enmod proxy_balancer &>> ${LOG}
a2enmod proxy_connect &>> ${LOG}
a2enmod proxy_html &>> ${LOG}
a2enmod ssl &>> ${LOG}

#Reverse-Proxy via Apache2
if [[ -z ${certurl} ]]; then
echo -e "Using HTTP..."
cat > /etc/apache2/sites-enabled/000-default.conf <<EOL
<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyPass / http://0.0.0.0:8080/
    ProxyPassReverse / http://0.0.0.0:8080/
    ServerName localhost
</VirtualHost>
EOL
else
# Certbot stuff
echo -e "Using HTTPS..."
if [[ ! -e /etc/letsencrypt/live/${certurl} ]]; then
    certbot -n --apache --register-unsafely-without-email --agree-tos -d ${certurl} &>> ${LOG}
    a2dissite 000-default.conf &>> ${LOG}
    cat > /etc/apache2/sites-enabled/000-default-le-ssl.conf <<EOL
<VirtualHost *:80>
    # Info
    ServerName ${certurl} 
    # Redirect any HTTP request to HTTPS
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =${certurl}
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
<VirtualHost *:443>
    # Info
    ServerName ${certurl}
    SSLEngine On
    SSLProxyEngine On
    ProxyRequests Off
    # SSL
    Include /etc/letsencrypt/options-ssl-apache.conf
    SSLCertificateFile /etc/letsencrypt/live/${certurl}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${certurl}/privkey.pem
    #Proxy
    ProxyPreserveHost On
    ProxyHTMLInterp On
    ProxyHTMLExtended On
    ProxyHTMLURLMap (.*)localhost(.*) https://${certurl} [Rin]
        ProxyPass / http://localhost:8080/
        ProxyPassReverse / http://localhost:8080/
    </VirtualHost>
EOL
    fi
fi

#tomcat
echo "Hardening Tomcat..."
service tomcat9 stop
sed -i "71 i \               server = \" \"" /var/lib/tomcat9/conf/server.xml

cat >> /var/lib/tomcat9/webapps/ROOT/error.jsp <<EOL
<!doctype html>
<title>Something went wrong!</title>
<style>
body { text-align: center; padding: 50px; background-color:#2d2d2d; color:#fff; }
h1 { font-size: 40px; text-align:center; }
body { font: 16px Helvetica, sans-serif; color: #fff;text-align:center;}
article { display: block; text-align: left; width: 850px; margin: 0 auto; }
a { color: #dc8100; text-decoration: none; }
a:hover { color: #fff; text-decoration: none; }
p{text-align:center;}
</style>
<article>
<div align="center">
<img src="https://i.imgur.com/uGKgx3F.png" width="200px">
<h1>RIP In Peace</h1>
<p>If you can not find what you are looking for please contact an admin.</p>
</div>
<h1><a href="/">Go back</a></h1>
</article>
EOL

cat >> /var/lib/tomcat9/webapps/ROOT/robots.txt <<EOL
User-agent: *
Disallow: /
EOL

cat >> errorpg.txt <<EOL
    <!-- Error page -->
    <error-page> 
      <error-code>404</error-code> 
      <location>/error.jsp</location>
    </error-page>
    <error-page> 
      <error-code>403</error-code> 
      <location>/error.jsp</location>
    </error-page>
    <error-page> 
      <error-code>500</error-code> 
      <location>/error.jsp</location>
    </error-page>
    <error-page>
      <exception-type>java.lang.Throwable</exception-type>
      <location>/error.jsp</location>
    </error-page>
EOL

sed -i '/<\/welcome-file-list>/r errorpg.txt' /var/lib/tomcat9/conf/web.xml
chown -R tomcat:tomcat /var/lib/tomcat9/

# restart tomcat
service tomcat9 restart
service apache2 restart

# Configure guacamole.properties
rm -f /etc/guacamole/guacamole.properties
touch /etc/guacamole/guacamole.properties
echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: ${guacPwd}" >> /etc/guacamole/guacamole.properties

# Create $guacDb and grant $guacUser permissions to it
echo "Building DB..."

# SQL code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by \"${guacPwd}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"

# Execute SQL code
echo ${SQLCODE} | mysql -u root -p$mysqlRootPwd &>> ${LOG}

# Create student accounts
echo "Creating Accounts..."
conid=1
counter=1
while  [ $counter -le $useramount ]
do
newstart="$((${hoststart} + ${counter}))"
hostip="${regionip}${newstart}"
cat >> newusers.sql <<EOL
SET @salt = UNHEX(SHA2(UUID(), 256));
INSERT INTO guacamole_entity (name, type)
VALUES ('${user}${counter}', 'USER');
INSERT INTO guacamole_user (
    entity_id,
    password_salt,
    password_hash,
    password_date,
    expired
)
SELECT
    entity_id,
    @salt,
    UNHEX(SHA2(CONCAT('${pass}', HEX(@salt)), 256)),
    CURRENT_TIMESTAMP,
    1
FROM guacamole_entity
WHERE
    name = '${user}${counter}'
    AND type = 'USER';

INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
FROM (
          SELECT '${user}${counter}' AS username, '${user}${counter}' AS affected_username, 'READ'       AS permission
    UNION SELECT '${user}${counter}' AS username, '${user}${counter}' AS affected_username, 'UPDATE'     AS permission
) permissions
JOIN guacamole_entity          ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
JOIN guacamole_entity affected ON permissions.affected_username = affected.name AND guacamole_entity.type = 'USER'
JOIN guacamole_user            ON guacamole_user.entity_id = affected.entity_id;

INSERT INTO guacamole_connection 
VALUES (${conid},'${user}${counter}-Ubuntu',NULL,'${proto}',NULL,NULL,NULL,${maxcons},${maxcons},NULL,0);
INSERT INTO guacamole_connection_parameter
VALUES (${conid},'hostname','${hostip}'),(${conid},'password','${rdppassword}'),(${conid},'username','${rdpuser}'),(${conid},'port','${rdpport}');
INSERT INTO guacamole_connection_permission 
VALUES (${counter},${conid},'READ'); 
EOL
((counter++))
((conid++))
((conid++))
done

hostip="${regionip}${hoststart}"
cat >> adminuser.sql <<EOL
-- Generate salt
SET @salt = UNHEX(SHA2(UUID(), 256));

-- Create base entity entry for user
INSERT INTO guacamole_entity (name, type)
VALUES ('${adminuser}', 'USER');

-- Create user and hash password with salt
INSERT INTO guacamole_user (
    entity_id,
    password_salt,
    password_hash,
    password_date
)
SELECT
    entity_id,
    @salt,
    UNHEX(SHA2(CONCAT('${adminpass}', HEX(@salt)), 256)),
    CURRENT_TIMESTAMP
FROM guacamole_entity
WHERE
    name = '${adminuser}'
    AND type = 'USER';
    
-- Grant this user all system permissions
INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, permission
FROM (
          SELECT '${adminuser}'  AS username, 'CREATE_CONNECTION'       AS permission
    UNION SELECT '${adminuser}'  AS username, 'CREATE_CONNECTION_GROUP' AS permission
    UNION SELECT '${adminuser}'  AS username, 'CREATE_SHARING_PROFILE'  AS permission
    UNION SELECT '${adminuser}'  AS username, 'CREATE_USER'             AS permission
    UNION SELECT '${adminuser}'  AS username, 'CREATE_USER_GROUP'       AS permission
    UNION SELECT '${adminuser}'  AS username, 'ADMINISTER'              AS permission
) permissions
JOIN guacamole_entity ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER';

-- Grant admin permission to read/update/administer self
INSERT INTO guacamole_user_permission (entity_id, affected_user_id, permission)
SELECT guacamole_entity.entity_id, guacamole_user.user_id, permission
FROM (
          SELECT '${adminuser}' AS username, '${adminuser}' AS affected_username, 'READ'       AS permission
    UNION SELECT '${adminuser}' AS username, '${adminuser}' AS affected_username, 'UPDATE'     AS permission
    UNION SELECT '${adminuser}' AS username, '${adminuser}' AS affected_username, 'ADMINISTER' AS permission
) permissions
JOIN guacamole_entity          ON permissions.username = guacamole_entity.name AND guacamole_entity.type = 'USER'
JOIN guacamole_entity affected ON permissions.affected_username = affected.name AND guacamole_entity.type = 'USER'
JOIN guacamole_user            ON guacamole_user.entity_id = affected.entity_id;

INSERT INTO guacamole_connection 
VALUES (${conid},'${adminuser}-Ubuntu',NULL,'${proto}',NULL,NULL,NULL,${maxcons},${maxcons},NULL,0);
INSERT INTO guacamole_connection_parameter
VALUES (${conid},'hostname','${hostip}'),(${conid},'password','${rdppassword}'),(${conid},'username','${rdpuser}'),(${conid},'port','${rdpport}');
INSERT INTO guacamole_connection_permission 
VALUES (${counter},${conid},'READ');
EOL

# Add Guacamole schema to newly created database
echo "Adding Tables..."
cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/001-create-schema.sql | mysql -u root -p$mysqlRootPwd guacamole_db &>> ${LOG}
cat newusers.sql | mysql -u root -p$mysqlRootPwd guacamole_db &>> ${LOG}
cat adminuser.sql | mysql -u root -p$mysqlRootPwd guacamole_db &>> ${LOG}
service guacd start

# Get Hard
echo "Hardening System..."
#put back in later

# Cleanup
echo "Spring Cleaning..."
rm -rf guacamole-*
rm -rf mysql-connector-java-*
rm newusers.sql
rm errorpg.txt
rm adminuser.sql
apt-get -yqq autoremove &>> ${LOG}
apt-get -yqq autoclean &>> ${LOG}

# Done
echo "Installation Complete!" 
