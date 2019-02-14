require 'yaml'

Vagrant.configure("2") do |config|
  settings = YAML::load(File.read('config.yaml'))
  hostname = "valhalla"

  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = hostname
  config.ssh.forward_agent = true
  config.vm.synced_folder "./", "/valhalla"

  if settings.include? "ip"
    config.vm.network "public_network", ip: settings["ip"]
  else
    config.vm.network "private_network", type: "dhcp"
    config.vm.network "forwarded_port", guest: 53, host: 53, protocol: "udp"
  end

  config.vm.provider :virtualbox do |vb|
    vb.gui = false
    vb.customize [
      "modifyvm", :id,
      "--cpuexecutioncap", settings["cpuexecutioncap"],
      "--memory", settings["memory"],
      "--cpus", settings["cpus"],
      "--ostype", "Ubuntu_64"
    ]
  end

  config.vm.provision "shell", name: "initializing valhalla", inline: <<-SHELL
    add-apt-repository ppa:shevchuk/dnscrypt-proxy
    apt update
    apt install -y dnsmasq figlet libsodium-dev git php7.2-cli dnscrypt-proxy libyaml-dev php7.2-yaml
    apt install -y nload iftop nethogs htop nmap vnstat tcptrack
    apt remove -y snapd
  SHELL

  cfg = "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

  config.vm.provision "shell", name: "configuring dnscrypt", args: [cfg], inline: <<-SHELL
    ln -fsv /valhalla/system/dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml
    service dnscrypt-proxy restart
  SHELL

  # set up the firewall options
  config.vm.provision "shell", name: "configure ufw", path: "./system/firewall.sh"

  config.vm.provision "shell", name: "configure logrotate", inline: <<-SHELL
    mkdir -p /var/log/dnsmasq ; chown dnsmasq:root /var/log/dnsmasq
    cp -f /valhalla/system/logrotate /etc/logrotate.d/dnsmasq
    chmod 644 /etc/logrotate.d/dnsmasq
  SHELL

  if File.exists? File.expand_path("~/.ssh/id_rsa.pub")
    config.vm.provision "shell" do |s|
      s.name = "adding public key found at ~/.ssh/id_rsa.pub to authorized_keys"
      s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys"
      s.args = [File.read(File.expand_path("~/.ssh/id_rsa.pub"))]
    end
  end
  
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    byobu-enable
  SHELL

  if settings.include? "ip"
    config.vm.provision "shell", run: "always", name: "obtain dhcp ips for display", inline: <<-SHELL
      ifconfig enp0s8 | awk '{$1=$1;print}' | grep 'inet ' | cut -d' ' -f 2 > /var/tmp/ip4
      ifconfig enp0s8 | awk '{$1=$1;print}' | grep 'link'  | cut -d' ' -f 2 > /var/tmp/ip6
    SHELL
  else
    config.vm.provision "shell", run: "always", name: "obtain bridge ips for display", inline: <<-SHELL
      echo '127.0.0.1' > /var/tmp/ip4
      echo '::1' > /var/tmp/ip6
    SHELL
  end
  
  config.vm.provision "shell", run: "always", name: "finishing startup process", inline: <<-SHELL
    # link bashrc file in repo to one in profile
    cat /home/vagrant/.bashrc | grep valhalla || echo '. /valhalla/system/.bashrc' >> /home/vagrant/.bashrc
	
    # build rulesets
    php /valhalla/system/valhalla.php 3p
    php /valhalla/system/valhalla.php build

    # enable byobu for root user
    byobu-enable

    # display banner message
    figlet valhalla
    echo '*'
    echo '* build complete!'
    echo "* please use 'vagrant ssh' to see the valhalla commandline options"
    echo '*'
    echo '* https://github.com/mmeyer2k/valhalla'
    echo '*'
    echo '* ipv4 address:' $(cat /var/tmp/ip4)
    echo '* ipv6 address:' $(cat /var/tmp/ip6)
    echo '*'
    echo '* dns server port: 53'
    echo '*'
  SHELL
end
