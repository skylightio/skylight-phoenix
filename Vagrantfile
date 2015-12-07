# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu/trusty64"

  # Used for the Phoenix example app.
  config.vm.network "forwarded_port", guest: 4000, host: 4000

  config.vm.synced_folder ".", "/direwolf-phoenix-agent"
  config.vm.synced_folder "../skylight-rust", "/skylight-rust"

  # Provisioning
  config.vm.provision "shell", path: "vagrant-provision.sh"
end
