#!/bin/bash
###################################################################
#Script Name	:  setupHAProxy.sh                                                                                            
#Description	:  Configure Jenkins master with HA Proxy                                                                              
#Args           :  None                                                                                          
#Author         :  Cory R. Stein                                                  
###################################################################

echo "Executing [$0]..."
PROGNAME=$(basename $0)

set -e

####################################################################
# Install packages
####################################################################
echo "Installing packages..."
yum install epel-release -y
#yum install https://$(rpm -E '%{?centos:centos}%{!?centos:rhel}%{rhel}').iuscommunity.org/ius-release.rpm -y
wget https://centos7.iuscommunity.org/ius-release.rpm -O /tmp/ius-release.rpm
rpm -Uvh /tmp/ius-release.rpm
yum install haproxy18u -y
echo "Completed installing packages"
####################################################################

####################################################################
# Configure HA Proxy
####################################################################
echo "Configuring HA Proxy..."
fqdn=$(hostname -f)

mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

#GLZCBJENAPLV001.rjc2i0zzwszutcvvznvt15tptb.bx.internal.cloudapp.net
cat > /etc/haproxy/haproxy.cfg << EOL
global
        log 127.0.0.1   local0
        log 127.0.0.1   local1 notice
        maxconn 4096
        user haproxy
        group haproxy

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # Default ciphers to use on SSL-enabled listening sockets.
        # For more information, see ciphers(1SSL). This list is from:
        #  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
        ssl-default-bind-ciphers FFF+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
        ssl-default-bind-options no-sslv3

        tune.ssl.default-dh-param 2048

defaults
        log    global
        option    http-server-close
        option    log-health-checks
        option    dontlognull
        timeout    http-request    10s
        timeout    queue           1m
        timeout    connect         5000
        timeout    client          50000
        timeout    server          50000
        timeout    http-keep-alive 10s
        timeout    check           500
        default-server inter 5s downinter 500 rise 1 fall 1

#redirect HTTP to HTTPS
listen http-in
        bind    *:80
        mode    http
        #redirect scheme https code 301 if !{ ssl_fc }
        # alpha and beta should be replaced with hostname (or ip) and port
        # 8888 is the default for CJOC, 8080 is the default for Client Masters
        server    alpha $(fqdn):8080
EOL

echo "Completed configuring HA Proxy"
####################################################################

#######################################
# Enable and start HA Proxy
#######################################
echo "Enabing and starting HA Proxy..."
systemctl enable haproxy.service
systemctl start haproxy.service
systemctl status haproxy.service
echo "Completed enabling and starting HA Proxy"
#######################################

echo "Executing [$0] complete"
exit 0
