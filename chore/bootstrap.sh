#!/usr/bin/env bash

set -e

ETCD_VER=v3.2.14
DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
ETCD_PATH=/opt/etcd

# instal and check etcd
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
echo checking instalation
etcd --version
etcdctl --version

echo set up mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

echo full system update
yes | pacman -Syyu &> /dev/null

echo done
