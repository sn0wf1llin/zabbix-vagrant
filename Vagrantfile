Vagrant.configure(2) do |config|

  config.vm.define "zabbix.lab.server" do |server|
    server.vm.box = "sbeliakou/centos"
  	config.vm.network "private_network", ip: "192.168.33.10"

    server.vm.provision "shell", path: "build.sh", args: "server", privileged: true
    server.vm.hostname = "zabbix.lab.server"
  end

  config.vm.define "zabbix.lab.agent.passive" do |agent|
    agent.vm.box = "sbeliakou/centos"
  	config.vm.network "private_network", ip: "192.168.33.11"

    agent.vm.provision "shell", path: "build.sh", args: "agent passive 192.168.33.10", privileged: true
    agent.vm.hostname = "zabbix.lab.agent"
  end

  config.vm.define "zabbix.lab.agent.active" do |agent|
    agent.vm.box = "sbeliakou/centos"
    config.vm.network "private_network", ip: "192.168.33.12"

    agent.vm.provision "shell", path: "build.sh", args: "agent active 192.168.33.10", privileged: true
    agent.vm.hostname = "zabbix.lab.agent"
  end

end