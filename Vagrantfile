require 'yaml'

Vagrant.configure("2") do |config|
  settings = YAML::load(File.read('valhalla.yaml'))
  hostname = "valhalla"

  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = hostname
  config.ssh.forward_agent = true
  config.vm.network "forwarded_port", guest: 53, host: 53, protocol: "udp"
  config.vm.network "forwarded_port", guest: 8888, host: 8888, protocol: "tcp"
  config.vm.synced_folder "./", "/valhalla"

  if settings.has_key?("ip")
    config.vm.network "public_network", ip: settings["ip"]
  else
    config.vm.network "private_network", type: "dhcp"
  end

  if Vagrant.has_plugin?("vagrant-hostsupdater")
    config.hostsupdater.aliases = [hostname]
    config.hostsupdater.ips = [settings["ip"] ||= '127.0.0.1']
  end

  config.vm.provider :virtualbox do |vb|
    vb.name = hostname
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
    apt install -y dnsmasq figlet libsodium-dev git php7.2-cli dnscrypt-proxy openvpn squid libyaml-dev php7.2-yaml
    apt install -y nload iftop nethogs htop nmap vnstat tcptrack
    apt remove -y snapd
  SHELL

  cfg = "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

  config.vm.provision "shell", name: "configuring dnscrypt", args: [cfg], inline: <<-SHELL
    sed -i 's|require_dnssec = .*|require_dnssec = true|' $1
    sed -i 's|ipv6_servers = .*|ipv6_servers = true|' $1
    service dnscrypt-proxy restart
  SHELL

  cfg = "/etc/squid/squid.conf"

  config.vm.provision "shell", name: "starting squid on 8888", args: [cfg], inline: <<-SHELL
    sed -i 's|http_access deny all|http_access allow all|' $1
    sed -i 's|http_port 3128|http_port 8888|' $1
    sed -i 's|#       Example: dns_nameservers .*|dns_nameservers 127.0.0.1|' $1
    sed -i 's|dns_nameservers .*|dns_nameservers 127.0.0.1|' $1
    service squid restart
  SHELL

  if settings.has_key?("vpnconf")
    config.vm.provision "shell", name: "rigging openvpn for silent running", args: [settings["vpnconf"], settings["vpnauth"]], inline: <<-SHELL
      php /valhalla/system/valhalla.php vpn $1 $2
      service openvpn-client restart
    SHELL
  end

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

  config.vm.provision "shell", name: "configure ufw", inline: <<-SHELL
	yes | ufw reset
	ufw default deny incoming
	ufw default allow outgoing
	ufw allow 22
	ufw allow 53
	ufw allow 8888
	ufw logging on
	ufw enable
  SHELL
  
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
	byobu-enable
  SHELL
  
  config.vm.provision "shell", run: "always", name: "finishing startup process", inline: <<-SHELL
	
    # link bashrc file in repo to one in profile
    cat /home/vagrant/.bashrc | grep valhalla || echo '. /valhalla/system/.bashrc' >> /home/vagrant/.bashrc
	
    # build rulesets
    php /valhalla/system/valhalla.php 3p
    php /valhalla/system/valhalla.php build

	byobu-enable

    # display banner message
    figlet valhalla
    echo '*'
    echo '* build complete!'
    echo "* please use 'vagrant ssh' to see valhalla's commandline options"
    echo '*'
    echo '* https://github.com/mmeyer2k/valhalla'
    echo '*'
  SHELL
end
