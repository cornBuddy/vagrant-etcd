# -*- mode: ruby -*-
# vi: set ft=ruby :

VM_BOX = "centos/7"
BOX_VERSION = "1801.02"
ETCD_SERVER_PORT = "2380"
ETCD_CLIENT_PORT = "2379"
ETCD_INITIAL_CLUSTER_TOKEN = "etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE = "new"
ETCD_HOME = "/var/lib/etcd"
ETCD_PATH = "/opt/etcd"
ETCD_ROOT_PWD = "root"
ETCD_CLUSTERS = [
  { name: "infra1", ip_addr: "192.168.0.11" },
  { name: "infra2", ip_addr: "192.168.0.12" },
  { name: "infra3", ip_addr: "192.168.0.13" },
]
ETCD_INITIAL_CLUSTER = ETCD_CLUSTERS
  .map do |cluster_config|
    "#{cluster_config[:name]}=http://#{cluster_config[:ip_addr]}"\
      ":#{ETCD_SERVER_PORT}"
  end
  .join(",")
ETCD_ENDPOINTS = ETCD_CLUSTERS
  .map do |cluster_config|
    "http://#{cluster_config[:ip_addr]}:#{ETCD_CLIENT_PORT}"
  end
  .join(",")
IP_LIST = ETCD_CLUSTERS
  .map { |c| c[:ip_addr] }
  .join(",")

FRONTEND = { name: "frontend", ip_addr: "192.168.0.20" }

def install_and_configure_etcd(cluster, cluster_config)
  cluster.vm.network "private_network", ip: cluster_config[:ip_addr]
  cluster.vm.box = VM_BOX
  cluster.vm.box_version = BOX_VERSION
  cluster.vm.provision :shell, path: "chore/system-bootstrap.sh",
    env: { "ETCD_HOME" => ETCD_HOME }, run: "always"
  cluster.vm.provision :shell, path: "chore/setup-ssh.sh", run: "always"
  cluster.vm.provision :shell, path: "chore/install-etcd.sh", args: IP_LIST,
    env: { "ETCD_PATH" => ETCD_PATH }, run: "always"
  env = {
    "ETCD_IP" => cluster_config[:ip_addr],
    "ETCD_NAME" => cluster_config[:name],
    "ETCD_ENDPOINTS" => ETCD_ENDPOINTS,
    "ETCD_SERVER_PORT" => ETCD_SERVER_PORT,
    "ETCD_CLIENT_PORT" => ETCD_CLIENT_PORT,
    "ETCD_INITIAL_CLUSTER_TOKEN" => ETCD_INITIAL_CLUSTER_TOKEN,
    "ETCD_INITIAL_CLUSTER" => ETCD_INITIAL_CLUSTER,
    "ETCD_INITIAL_CLUSTER_STATE" => ETCD_INITIAL_CLUSTER_STATE,
    "ETCD_HOME" => ETCD_HOME,
    "ETCD_PATH" => ETCD_PATH,
    "ROOT_PWD" => ETCD_ROOT_PWD,
  }
  cluster.vm.provision :shell, path: "chore/setup-systemd.sh",
    env: env, args: IP_LIST, run: "always"
  yield if block_given?
end

Vagrant.configure("2") do |config|
  (ETCD_CLUSTERS.first ETCD_CLUSTERS.size - 1).each do |cluster_config|
    config.vm.define cluster_config[:name] do |cluster|
      install_and_configure_etcd(cluster, cluster_config)
    end
  end

  last = ETCD_CLUSTERS.last
  config.vm.define last[:name] do |cluster|
    install_and_configure_etcd(cluster, last) do
      cluster.vm.provision :shell, path: "chore/configure-etcd-policies.sh",
        env: { "ROOT_PWD" => ETCD_ROOT_PWD }
    end
  end

  config.vm.define FRONTEND[:name] do |frontend|
    frontend.vm.network "private_network", ip: FRONTEND[:ip_addr]
    frontend.vm.box = VM_BOX
    frontend.vm.box_version = BOX_VERSION
    frontend.vm.provision :shell, path: "chore/run-e3w.sh", run: "always",
      args: ETCD_ENDPOINTS
    frontend.vm.network "forwarded_port", guest: 80, host: 8080
  end
end
