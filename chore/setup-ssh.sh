#!/usr/bin/env bash

set -e


echo configuring sshd
sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" \
    /etc/ssh/sshd_config
systemctl restart sshd.service

if which sshpass &> /dev/null; then
    echo sshpass is installed
else
    echo installing sshpass
    yum -y install sshpass &> /dev/null
fi
