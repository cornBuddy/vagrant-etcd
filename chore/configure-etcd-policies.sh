#!/usr/bin/env bash

CREDS="--user root:$ROOT_PWD"

set -e

is_root_user_exists() {
    if etcdctl user list | grep root; then
        return 0
    else
        return 1
    fi
}

are_roles_created() {
    if etcdctl role list | grep -E "dev|op"; then
        return 0
    else
        return 1
    fi
}

create_user_if_not_exists() {
    if echo $1 | etcdctl --interactive=false user add $1 &> /dev/null; then
        echo user $1 was created
    else
        echo user $1 is already exist
    fi
}

echo configuring policies
if is_root_user_exists; then
    echo root exists
    etcdctl $CREDS auth disable &> /dev/null
else
    echo adding root user
    echo $ROOT_PWD | etcdctl --interactive=false user add root
    etcdctl user grant-role root root
fi

if are_roles_created; then
    echo roles exist
else
    echo adding roles
    etcdctl role add dev
    etcdctl role add op
fi

echo creating roles
etcdctl role grant-permission op --prefix=true readwrite mongo/ &> /dev/null
etcdctl role grant-permission dev --prefix=true read mongo/ &> /dev/null

echo creating users
create_user_if_not_exists dave
create_user_if_not_exists odin

echo granting roles for users
etcdctl user grant-role dave dev &> /dev/null
etcdctl user grant-role odin op &> /dev/null

etcdctl auth enable
