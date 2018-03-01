#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
    echo no ip list provided
    exit 1
fi

SSH_OPTS="-o \"StrictHostKeyChecking=no\""

ETCD_CONFIG_PATH=/etc/etcd/etcd.conf
ETCD_SERVICE_PATH=/etc/systemd/system/etcd.service
ETCD_DATA_DIR="$ETCD_HOME/$ETCD_NAME.etcd"
ETCD_BACKUP="$ETCD_HOME/snapshot.db"
ETCD_SERVER="http://$ETCD_IP:$ETCD_SERVER_PORT"
ETCD_CLIENT="http://$ETCD_IP:$ETCD_CLIENT_PORT"
ETCD_CREDS="--user root:$ROOT_PWD"

read -r -d '' ETCD_BACKUP_SERVICE_TIMER << EOF || true
[Unit]
Description=etcd backup hourly timer
[Timer]
OnUnitActiveSec=0min
OnCalendar=*-*-* *:00:00
Persistent=true
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

read -r -d '' ETCD_RESTORE_MEMBER_SCRIPT << EOF || true
#!/bin/sh -
cd $ETCD_HOME
echo restoring $ETCD_NAME
systemctl stop etcd.service
mkdir -p $ETCD_HOME
rm -rf $ETCD_DATA_DIR
ETCDCTL_API=3 $ETCD_PATH/etcdctl $ETCD_CREDS snapshot restore $ETCD_BACKUP \\
    --name $ETCD_NAME \\
    --initial-cluster $ETCD_INITIAL_CLUSTER \\
    --initial-cluster-token $ETCD_INITIAL_CLUSTER_TOKEN \\
    --initial-advertise-peer-urls $ETCD_SERVER \\
    --skip-hash-check
chown -R etcd:etcd $ETCD_HOME
EOF

read -r -d '' ETCD_RESTORE_SCRIPT << EOF || true
#!/bin/sh -
echo taking snapshot from current machine
systemctl stop etcd-backup.service
systemctl start etcd-backup.service
ips=\`echo "$1" | tr "," "\n"\`
for ip in \$ips; do
    echo restoring home dir on \$ip
    sshpass -p root ssh $SSH_OPTS root@\$ip "mkdir -p $ETCD_HOME"
    echo copying snapshot to \$ip
    sshpass -p root scp $SSH_OPTS $ETCD_BACKUP root@\$ip:$ETCD_BACKUP
    echo running restore member script on \$ip
    sshpass -p root ssh $SSH_OPTS root@\$ip "/usr/bin/etcd-restore-member"
    echo starting etcd.service on \$ip
    sshpass -p root ssh $SSH_OPTS root@\$ip "systemctl --no-block start etcd.service"
done

sshpass -p root ssh $SSH_OPTS root@$2 "cd /data/e3w && docker-compose kill"
sshpass -p root ssh $SSH_OPTS root@$2 "cd /data/e3w && docker-compose up -d --no-recreate"
EOF

read -r -d '' ETCD_BACKUP_SCRIPT << EOF || true
#!/bin/sh -
ETCDCTL_API=3 $ETCD_PATH/etcdctl $ETCD_CREDS --endpoints $ETCD_ENDPOINTS \\
    snapshot save $ETCD_BACKUP
EOF
configure_etcd_service() {
    echo creating etcd service
    mkdir -p /etc/etcd
    echo "$ETCD_ENV" > $ETCD_CONFIG_PATH
    echo "$ETCD_SERVICE" > $ETCD_SERVICE_PATH
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
}

start_etcd() {
    echo enabling and starting etcd service
    systemctl daemon-reload
    systemctl enable --no-block etcd.service
    systemctl start --no-block etcd.service
    systemctl enable --no-block etcd-backup.service
    systemctl start --no-block etcd-backup.service
    systemctl enable etcd-backup.timer
    systemctl start etcd-backup.timer
}

configure_etcd_service
generate_distaster_scripts
start_etcd
