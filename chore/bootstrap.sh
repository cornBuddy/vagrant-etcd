#!/usr/bin/env bash

set -e

ETCD_VER=v3.2.14
GITHUB_ETCD=https://github.com/coreos/etcd/releases/download
DOWNLOAD_URL="$GITHUB_ETCD/$ETCD_VER/etcd-$ETCD_VER-linux-amd64.tar.gz"
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
ETCD_PATH=/opt/etcd
ETCD_CONFIG_PATH=/etc/etcd/etcd.conf
ETCD_HOME=/var/lib/etcd/
ETCD_DATA_DIR="$ETCD_HOME/default.etcd"
ETCD_SERVICE_PATH=/etc/systemd/system/etcd.service

ETCD_SERVER="http://$ETCD_IP:$ETCD_SERVER_PORT"
ETCD_CLIENT="http://$ETCD_IP:$ETCD_CLIENT_PORT"
read -r -d '' ETCD_ENV << EOF || true
# [member]
ETCD_NAME=$ETCD_NAME
ETCD_DATA_DIR=$ETCD_DATA_DIR
ETCD_LISTEN_CLIENT_URLS=$ETCD_CLIENT,http://127.0.0.1:$ETCD_CLIENT_PORT
ETCD_ADVERTISE_CLIENT_URLS=$ETCD_CLIENT
ETCD_LISTEN_PEER_URLS=$ETCD_SERVER
# [cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS=$ETCD_SERVER
ETCD_INITIAL_CLUSTER=$ETCD_INITIAL_CLUSTER
ETCD_INITIAL_CLUSTER_TOKEN=$ETCD_INITIAL_CLUSTER_TOKEN
ETCD_INITIAL_CLUSTER_STATE=$ETCD_INITIAL_CLUSTER_STATE
EOF

read -r -d '' ETCD_SERVICE << EOF || true
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
After=network.target

[Service]
Type=notify
WorkingDirectory=$ETCD_HOME
EnvironmentFile=-$ETCD_CONFIG_PATH
User=etcd
ExecStart=$ETCD_PATH/etcd
LimitNOFILE=65536
Restart=always
RestartSec=5

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

is_etcd_service_created() {
    if [ -f $ETCD_SERVICE_PATH ]; then
        return 0
    else
        return 1
    fi
}

configure_etcd_service() {
    echo creating etcd service
    echo "$ETCD_ENV" > $ETCD_CONFIG_PATH
    echo "$ETCD_SERVICE" > $ETCD_SERVICE_PATH
    systemctl daemon-reload
}

enable_etcd_service() {
    echo enabling and starting etcd service
    systemctl enable --no-block etcd.service
    systemctl start --no-block etcd.service
}

install_and_configure_etcd() {
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
    echo "export ETCDCTL_API=3" >> /etc/profile
    echo basic configuration
    mkdir $ETCD_HOME
    mkdir /etc/etcd
    groupadd --system etcd
    useradd --system \
        --gid etcd \
        --home-dir $ETCD_HOME \
        --shell /sbin/nologin \
        --comment "etcd user" \
        etcd
    chown -R etcd:etcd $ETCD_HOME
}

if is_etcd_installed; then
    echo etcd is installed
else
    install_and_configure_etcd
fi

if is_etcd_service_created; then
    echo etcd service created
else
    configure_etcd_service
    enable_etcd_service
fi
