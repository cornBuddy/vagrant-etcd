#!/usr/bin/env bash

set -e

echo configuring system

if id -u etcd &> /dev/null; then
    echo etcd user alredy exists
else
    echo adding etcd user
    mkdir -p $ETCD_HOME
    groupadd --system etcd
    useradd --system \
        --gid etcd \
        --no-create-home \
        --home-dir $ETCD_HOME \
        --shell /bin/bash \
        --comment "etcd user" \
        etcd
    echo etcd:etcd | chpasswd
    echo root:root | chpasswd
    chown -R etcd:etcd $ETCD_HOME
    echo configuring sudo
    s1="Cmnd_Alias ETCD ="
    s1+=" /bin/systemctl start --no-block etcd.service"
    s1+=", /bin/systemctl stop etcd.service"
    s1+=", /bin/systemctl status etcd.service"
    s2="%etcd ALL=(ALL) NOPASSWD: ETCD"
    echo "$s1" >> /etc/sudoers
    echo "$s2" >> /etc/sudoers
fi
