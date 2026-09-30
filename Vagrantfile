Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = true

  nodes = {
    "k8s-control" => { ip: "192.168.56.10", memory: 3072, cpus: 2 },
    "k8s-worker1" => { ip: "192.168.56.11", memory: 2048, cpus: 2 },
    "k8s-worker2" => { ip: "192.168.56.12", memory: 2048, cpus: 2 }
  }

  nodes.each do |name, node|
    config.vm.define name do |machine|
      machine.vm.hostname = name
      machine.vm.network "private_network", ip: node[:ip]
      machine.vm.provider "virtualbox" do |vb|
        vb.name = "mern-#{name}"
        vb.memory = node[:memory]
        vb.cpus = node[:cpus]
      end
      if name == "k8s-control"
        machine.vm.network "forwarded_port", guest: 30080, host: 8080, auto_correct: true
        machine.vm.network "forwarded_port", guest: 30300, host: 30300, auto_correct: true
      end
    end
  end
end
