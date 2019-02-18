Vagrant.configure(2) do |config|

  config.vm.define "zabbix.lab.agent" do |agent|
    agent.vm.box = "sbeliakou/centos"
    agent.vm.network "private_network", ip: "192.168.33.22"

    agent.vm.provision "shell", path: "build.sh", args: "agent 192.168.33.10", privileged: true
    agent.vm.hostname = "zabbix.lab.agent"
  end

  config.vm.define "zabbix.lab.server" do |server|
    server.vm.box = "sbeliakou/centos"
  	config.vm.network "private_network", ip: "192.168.33.10"

    server.vm.provision "shell", path: "build.sh", args: "server", privileged: true
    server.vm.hostname = "zabbix.lab.server"
  end

  # config.vm.define "zabbix.lab.agent.passive" do |pagent|
  #   pagent.vm.box = "sbeliakou/centos"
  # 	pagent.vm.network "private_network", ip: "192.168.33.11"

  #   pagent.vm.provision "shell", path: "build.sh", args: "agent 192.168.33.10", privileged: true
  #   pagent.vm.hostname = "zabbix.lab.agent.passive"
  # end

  # config.vm.define "zabbix.lab.agent.active" do |aagent|
  #   aagent.vm.box = "sbeliakou/centos"
  #   aagent.vm.network "private_network", ip: "192.168.33.12"

  #   aagent.vm.provision "shell", path: "build.sh", args: "agent active 192.168.33.10", privileged: true
  #   aagent.vm.hostname = "zabbix.lab.agent.active"
  # end

end