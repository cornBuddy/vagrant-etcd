#!/bin/bash

set -e

echo installing docker
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo &> /dev/null
yum-config-manager --enable docker-ce-edge &> /dev/null
yum -y install docker-ce git python-pip epel-release &> /dev/null
yum -y install python-pip &> /dev/null
pip install docker-compose &> /dev/null
yum -y upgrade python* &> /dev/null

echo starting and configuring nginx
yum -y install nginx &> /dev/null
systemctl enable nginx
systemctl start nginx

echo starting docker
systemctl enable docker
systemctl start docker

echo pulling e3w
mkdir -p /data
cd /data
if [ ! -d ./e3w ]; then
    git clone https://github.com/soyking/e3w.git
fi

echo configuring e3w
cd e3w/conf
sed -i -- 's/^root_key=.*$/root_key=e3w/g' config.default.ini
sed -i -- 's|^addr=.*$|addr='"$1"'|g' config.default.ini
sed -i -- 's/^username=.*$/username=root/g' config.default.ini
sed -i -- 's/^password=.*$/password=root/g' config.default.ini
chown -R nginx /data
setsebool -P httpd_can_network_connect 1

echo configuring nginx
read -r -d '' NGINX_CONF << EOF || true
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;

        include /etc/nginx/default.d/*.conf;

        location / {
            proxy_pass http://127.0.0.1:8080;
        }
    }
}
EOF
echo "$NGINX_CONF" > /etc/nginx/nginx.conf
nginx -s reload

echo starting e3w
cd ../
docker-compose up -d --no-recreate &> /dev/null
