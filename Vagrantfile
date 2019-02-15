Vagrant.configure(2) do |config|

  config.vm.define "server" do |server|
    server.vm.box = "sbeliakou/centos7"
    config.vm.network "forwarded_port", guest: 80, host: 8080
  	config.vm.network "public_network"

    server.vm.provision "shell", path: "build.sh", args: "server", privileged: true
    server.vm.hostname = "zabbix.lab.server"
  end

  # config.vm.define "agent" do |agent|
  #   agent.vm.box = "sbeliakou/centos7"
  #   config.vm.network "forwarded_port", guest: 80, host: 8080
  # 	config.vm.network "public_network"

  #   agent.vm.provision "shell", path: "build.sh", args: "agent", privileged: true
  #   agent.vm.hostname = "zabbix.lab.agent"
  # end

end