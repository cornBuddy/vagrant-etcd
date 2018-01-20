# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "archlinux/archlinux"
  config.vm.provision :shell, path: "chore/bootstrap.sh", keep_color: false
  config.vm.box_version = "2018.01.07"
end
