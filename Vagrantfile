Vagrant.configure(2) do |config|

  config.vm.define "zabbix.lab.server" do |server|
    server.vm.box = "sbeliakou/centos"
    config.vm.network "forwarded_port", guest: 80, host: 8080
  	config.vm.network "private_network", ip: "192.168.33.10"

    server.vm.provision "shell", path: "build.sh", args: "server", privileged: true
    server.vm.hostname = "zabbix.lab.server"
  end

  # config.vm.define "zabbix.lab.agent" do |agent|
  #   agent.vm.box = "sbeliakou/centos"
  #   config.vm.network "forwarded_port", guest: 80, host: 8080
  # 	config.vm.network "private_network", ip: "192.168.33.11"

  #   agent.vm.provision "shell", path: "build.sh", args: "agent", privileged: true
  #   agent.vm.hostname = "zabbix.lab.agent"
  # end

end