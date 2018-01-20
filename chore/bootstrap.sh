#!/usr/bin/env bash

set -e

ETCD_VER=v3.2.14
DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
ETCD_PATH=/opt/etcd

if [ -x "$ETCD_PATH/etcd" -a -x "$ETCD_PATH/etcdctl" ]; then
    echo etcd is installed
else
    [ -f "$ETCD_ARCHIVE" ] && rm ${ETCD_ARCHIVE}
    echo downloading etcd archive
    curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz \
        -o ${ETCD_ARCHIVE} &> /dev/null
    [ -d "$ETCD_PATH" ] && rm -rf ${ETCD_PATH}
    mkdir ${ETCD_PATH}
    echo installing etcd
    tar xzvf ${ETCD_ARCHIVE} \
        -C ${ETCD_PATH} --strip-components=1 &> /dev/null
    echo cleaning up
    rm -f ${ETCD_ARCHIVE}
    echo setting up path
    ln -sf "$ETCD_PATH/etcd" /bin/etcd
    ln -sf "$ETCD_PATH/etcdctl" /bin/etcdctl
    echo "export ETCDCTL_API=3" >> /etc/profile
    echo checking instalation
fi

etcd --version
echo done
