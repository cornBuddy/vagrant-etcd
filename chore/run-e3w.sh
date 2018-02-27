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

echo starting docker
systemctl enable docker
systemctl start docker

echo pulling e3w
if [ ! -d ./e3w ]; then
    git clone https://github.com/soyking/e3w.git
fi

echo configuring e3w
cd e3w/conf
sed -i -- 's/^root_key=.*$/root_key=e3w/g' config.default.ini
sed -i -- 's|^addr=.*$|addr='"$1"'|g' config.default.ini
sed -i -- 's/^username=.*$/username=root/g' config.default.ini
sed -i -- 's/^password=.*$/password=root/g' config.default.ini

echo starting e3w
cd ../
docker-compose up
