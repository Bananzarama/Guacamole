#! /bin/bash

##NOTES
# Can't rdp to localhost, but you can ssh
# SQL is all around better
# Restart guacd/tomcat if user-mapping.xml is edited
###

VERSION="1.2.0"
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}"
TCVERSION="9"

#sudo check
if [[ "$EUID" -ne 0 ]]; then echo "Please run this script as sudo or root"; exit 1 ; fi

#update
apt update

#dependencies
apt install -y build-essential wget libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin \
libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev \
libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev apache2 libxml2-dev freerdp-x11

#other deps
apt install -y dpkg-dev tomcat${TCVERSION} tomcat${TCVERSION}-admin tomcat${TCVERSION}-common tomcat${TCVERSION}-user 


#downloads
cd ~
wget -q -O guacamole-server-${VERSION}.tar.gz ${SERVER}/source/guacamole-server-${VERSION}.tar.gz
wget -q -O guacamole-${VERSION}.war ${SERVER}/binary/guacamole-${VERSION}.war


#make server
tar -xzf guacamole-server-${VERSION}.tar.gz
mkdir /etc/guacamole
cd guacamole-server-${VERSION}
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
cd ~


#install client
mv guacamole-1.1.0.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/tomcat${TCVERSION}/webapps/
mkdir /etc/guacamole/{extensions,lib}
echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat${TCVERSION}
ln -s /etc/guacamole /usr/share/tomcat${TCVERSION}/.guacamole


#Tomcat splashpage
cat > /var/lib/tomcat${TCVERSION}/webapps/ROOT/index.html <<EOL
<html>
<head>
<meta http-equiv="Refresh" content="0; url=/guacamole/#/" />
<title>Guacamole Pit</title>
</head>
<body>
<h1><a href="/guacamole/#/">Guacamole</a></h1>
</body>
</html>
EOL
systemctl restart tomcat${TCVERSION}

#Apache mods
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_ajp
a2enmod rewrite
a2enmod deflate
a2enmod headers
a2enmod proxy_balancer
a2enmod proxy_connect
a2enmod proxy_html
a2enmod ssl

#Reverse-Proxy via Apache2
cat > /etc/apache2/sites-enabled/000-default.conf <<EOL
<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyPass / http://0.0.0.0:8080/
    ProxyPassReverse / http://0.0.0.0:8080/
    ServerName localhost
</VirtualHost>
EOL

cat > /etc/guacamole/guacamole.properties <<EOL
guacd-hostname: localhost
guacd-port:    4822
user-mapping:    /etc/guacamole/user-mapping.xml
auth-provider:    net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
EOL

#Guac user settings
mkdir /shared-folder
touch /etc/guacamole/user-mapping.xml 
cat > /etc/guacamole/user-mapping.xml <<EOL
<user-mapping>
    <authorize 
                username="student" 
                password="3ff9e046a7418d59de611c3fa78d2693" 
                encoding="md5">
                <connection name="Local RDP">
                        <protocol>rdp</protocol>
                        <param name="hostname">192.168.0.2</param>
                        <param name="username">student</param>
                        <param name="password">student</param>
                        <param name="enable-drive">true</param>
                        <param name="drive-path">/shared-folder</param>
                </connection>
        </authorize>
</user-mapping>
EOL
chmod 600 /etc/guacamole/user-mapping.xml
chown tomcat:tomcat /etc/guacamole/user-mapping.xml

#Security goes here

#Final restart
service apache2 restart
systemctl enable guacd
systemctl start guacd 
