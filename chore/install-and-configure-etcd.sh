#!/usr/bin/env bash

set -e


if [ -z "$1" ]; then
    echo no ip list provided
    exit 2
fi

ETCD_VER=v3.2.14
GITHUB_ETCD=https://github.com/coreos/etcd/releases/download
DOWNLOAD_URL="$GITHUB_ETCD/$ETCD_VER/etcd-$ETCD_VER-linux-amd64.tar.gz"
ETCD_ARCHIVE=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
ETCD_PATH=/opt/etcd
ETCD_CONFIG_PATH=/etc/etcd/etcd.conf
ETCD_BACKUP="$ETCD_HOME/snapshot.db"
ETCD_DATA_DIR="$ETCD_HOME/$ETCD_NAME.etcd"
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
Description=etcd cluster
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

read -r -d '' ETCD_BACKUP_SERVICE << EOF || true
[Unit]
Description=etcd backup
After=etcd.service

[Service]
Type=oneshot
User=etcd
ExecStart=/usr/bin/etcd-backup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

read -r -d '' ETCD_BACKUP_SERVICE_TIMER << EOF || true
[Unit]
Description=etcd backup hourly timer

[Timer]
OnUnitActiveSec=0min
OnCalendar=*-*-* *:00:00
Persistent=true
EOF

read -r -d '' ETCD_BACKUP_SCRIPT << EOF || true
#!/bin/sh -
ETCDCTL_API=3 $ETCD_PATH/etcdctl --endpoints $ETCD_ENDPOINTS \\
    snapshot save $ETCD_BACKUP
EOF

read -r -d '' ETCD_RESTORE_SCRIPT << EOF || true
#!/bin/sh -
ips=\`echo "$1" | tr "," "\n"\`
for ip in \$ips; do
    echo connecting to \$ip
    sshpass -p etcd ssh etcd@\$ip "/usr/bin/etcd-restore-member"
done
EOF

read -r -d '' ETCD_RESTORE_MEMBER_SCRIPT << EOF || true
#!/bin/sh -
cd $ETCD_HOME
echo restoring $ETCD_NAME
sudo systemctl stop etcd.service
rm -rf $ETCD_DATA_DIR
ETCDCTL_API=3 $ETCD_PATH/etcdctl snapshot restore $ETCD_BACKUP \\
    --name $ETCD_NAME \\
    --initial-cluster $ETCD_INITIAL_CLUSTER \\
    --initial-cluster-token $ETCD_INITIAL_CLUSTER_TOKEN \\
    --initial-advertise-peer-urls $ETCD_SERVER \\
    --skip-hash-check
sudo systemctl start --no-block etcd.service
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
    mkdir -p /etc/etcd
    echo "$ETCD_ENV" > $ETCD_CONFIG_PATH
    echo "$ETCD_SERVICE" > $ETCD_SERVICE_PATH
    systemctl daemon-reload
    echo enabling and starting etcd service
    systemctl enable --no-block etcd.service
    systemctl start --no-block etcd.service
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

generate_distaster_scripts() {
    echo generating backup scripts
    echo "$ETCD_BACKUP_SCRIPT" > /usr/bin/etcd-backup
    chmod +x /usr/bin/etcd-backup
    echo "$ETCD_RESTORE_SCRIPT" > /usr/bin/etcd-restore-cluster
    echo "$ETCD_RESTORE_MEMBER_SCRIPT" > /usr/bin/etcd-restore-member
    chmod +x /usr/bin/etcd-restore-cluster
    chmod +x /usr/bin/etcd-restore-member
    echo creating backup service
    echo "$ETCD_BACKUP_SERVICE" > /etc/systemd/system/etcd-backup.service
    echo "$ETCD_BACKUP_SERVICE_TIMER" > /etc/systemd/system/etcd-backup.timer
    systemctl daemon-reload
    systemctl enable --no-block etcd-backup.service
    systemctl start --no-block etcd-backup.service
    systemctl enable etcd-backup.timer
    systemctl start etcd-backup.timer
}

if is_etcd_installed; then
    echo etcd is installed
else
    install_etcd
fi

if is_etcd_service_created; then
    echo etcd service created
else
    configure_etcd_service
fi

generate_distaster_scripts
