#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
    echo no ip list provided
    exit 2
fi

echo checking etcd installation

ETCD_VER=v3.2.14
GITHUB_ETCD=https://github.com/coreos/etcd/releases/download
DOWNLOAD_URL="$GITHUB_ETCD/$ETCD_VER/etcd-$ETCD_VER-linux-amd64.tar.gz"
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

is_etcd_installed() {
    if [ -x "$ETCD_PATH/etcd" -a -x "$ETCD_PATH/etcdctl" ]; then
        return 0
    else
        return 1
    fi
}

install_etcd() {
    echo downloading etcd archive
    curl -L $DOWNLOAD_URL -o $ETCD_ARCHIVE &> /dev/null
    mkdir $ETCD_PATH
    echo installing etcd
    tar xzvf $ETCD_ARCHIVE -C $ETCD_PATH --strip-components=1 &> /dev/null
    echo cleaning up
    rm -f $ETCD_ARCHIVE
    echo setting up path
    ln -sf "$ETCD_PATH/etcd" /bin/etcd
    ln -sf "$ETCD_PATH/etcdctl" /bin/etcdctl
    echo "export ETCDCTL_API=3" >> /etc/environment
}

if is_etcd_installed; then
    echo etcd is installed
else
    install_etcd
fi
