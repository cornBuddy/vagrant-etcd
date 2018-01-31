# -*- mode: ruby -*-
# vi: set ft=ruby :

VM_BOX = "centos/7"
BOX_VERSION = "1801.02"
ETCD_SERVER_PORT = "2380"
ETCD_CLIENT_PORT = "2379"
ETCD_INITIAL_CLUSTER_TOKEN = "etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE = "new"
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

Vagrant.configure("2") do |config|
  ETCD_CLUSTERS.each do |cluster_config|
    config.vm.define cluster_config[:name] do |cluster|
      cluster.vm.network "private_network", ip: cluster_config[:ip_addr]
      cluster.vm.box = VM_BOX
      cluster.vm.box_version = BOX_VERSION
      env = {
        "ETCD_IP" => cluster_config[:ip_addr],
        "ETCD_NAME" => cluster_config[:name],
        "ETCD_ENDPOINTS" => ETCD_ENDPOINTS,
        "ETCD_SERVER_PORT" => ETCD_SERVER_PORT,
        "ETCD_CLIENT_PORT" => ETCD_CLIENT_PORT,
        "ETCD_INITIAL_CLUSTER_TOKEN" => ETCD_INITIAL_CLUSTER_TOKEN,
        "ETCD_INITIAL_CLUSTER" => ETCD_INITIAL_CLUSTER,
        "ETCD_INITIAL_CLUSTER_STATE" => ETCD_INITIAL_CLUSTER_STATE,
      }
      cluster.vm.provision :shell, path: "chore/bootstrap.sh",
        keep_color: false, env: env
    end
  end
end
