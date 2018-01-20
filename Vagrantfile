# -*- mode: ruby -*-
# vi: set ft=ruby :

VM_BOX = "archlinux/archlinux"
BOX_VERSION = "2018.01.07"
ETCD_CLUSTERS = ["infra0", "infra1", "infra2"]

Vagrant.configure("2") do |config|
  ETCD_CLUSTERS.each do |cluster_name|
    config.vm.define cluster_name do |cluster|
      cluster.vm.box = VM_BOX
      cluster.vm.provision :shell, path: "chore/bootstrap.sh", keep_color: false
      cluster.vm.box_version = BOX_VERSION
    end
  end
end
