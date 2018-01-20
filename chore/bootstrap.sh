#!/usr/bin/env bash

set -e

ETCD_VER=v3.2.14
DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
ETCD_PATH=/opt/etcd

read -r -d '' ETCD_SERVICE << EOF || true
[Unit]
Description=Etcd service
After=network.target
[Service]
Type=simple
PIDFile=/var/run/etcd.pid
WorkingDirectory=/opt/etcd
User=root
Group=root
ExecStart=/usr/bin/etcd
ExecStop=/usr/bin/kill -15 `/usr/bin/pidof etcd`
ExecReload=/usr/bin/kill -15 `/usr/bin/pidof etcd` ; /usd/bin/etcd
Restart=always
[Install]
WantedBy=multi-user.target
EOF

is_etcd_installed() {
    if [ -x "$ETCD_PATH/etcd" -a -x "$ETCD_PATH/etcdctl" ]; then
        return 0
    else
        return 1
    fi
}

install_and_setup_etcd() {
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
}

create_etcd_service() {
    echo creating etcd service
    echo "$ETCD_SERVICE" > /etc/systemd/system/etcd.service
}

enable_etcd_service() {
    echo enabling and starting etcd service
    systemctl enable etcd.service
    systemctl start etcd.service
}

if is_etcd_installed; then
    echo etcd is installed
else
    install_and_setup_etcd
    create_etcd_service
    enable_etcd_service
    echo checking instalation
    etcd --version
fi

echo done
