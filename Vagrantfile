require 'yaml'

Vagrant.configure("2") do |config|
  settings = YAML::load(File.read('config.yaml'))
  hostname = "valhalla"

  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = hostname
  config.ssh.forward_agent = true
  config.vm.synced_folder "./", "/valhalla"

  config.vm.network "private_network", type: "dhcp"

  if settings.include? "ip4"
    config.vm.network "public_network", ip: settings["ip4"]
  end

  if settings.include? "ip6"
    config.vm.network "public_network", ip: settings["ip6"]
  end

  config.vm.network "forwarded_port", guest: 80, host: 8888, protocol: "tcp"
  config.vm.network "forwarded_port", guest: 53, host: 53, protocol: "udp"
  config.vm.network "forwarded_port", guest: 22, host: 2288, protocol: "tcp"

  config.vm.provider :virtualbox do |vb|
    vb.gui = false
    vb.customize [
      "modifyvm", :id,
      "--memory", settings["memory"],
      "--cpus", settings["cpus"],
      "--ostype", "Ubuntu_64"
    ]
  end

  config.vm.provision "shell", inline: <<-SHELL
    ln -sf /valhalla/system/resolv.conf /etc/resolv.conf
  SHELL

  config.vm.provision "shell", name: "setting up valhalla", inline: <<-SHELL
    add-apt-repository ppa:shevchuk/dnscrypt-proxy
    apt update
    apt install -y dnsmasq figlet libsodium-dev git dnscrypt-proxy libyaml-dev tor
    apt install -y iftop nethogs htop nmap tcptrack multitail
    apt remove -y snapd
  SHELL

  config.vm.provision "shell", name: "installing nginx", inline: <<-SHELL
    apt install -y nginx
    service nginx enable
    service nginx start
  SHELL

  config.vm.provision "shell", name: "installing php", inline: <<-SHELL
    apt install -y php7.2-cli php7.2-yaml
  SHELL

  cfg = "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

  config.vm.provision "shell", name: "configuring dnscrypt", args: [cfg], inline: <<-SHELL
    sed -i 's|require_dnssec = .*|require_dnssec = true|' $1
    sed -i 's|ipv6_servers = .*|ipv6_servers = true|' $1
  SHELL

  if settings.include? "socks5"
    socks5 = '"' << settings["socks5"] << '"'
    config.vm.provision "shell", name: "enabling dnscrypt socks5 proxy", args: [cfg, socks5], inline: <<-SHELL
      sed -i "s|# proxy = .*|proxy = $2|" $1
      sed -i "s|proxy = .*|proxy = $2|" $1
      sed -i 's|force_tcp = .*|force_tcp = true|' $1
    SHELL
  else
    config.vm.provision "shell", name: "disabling dnscrypt socks5 proxy", args: [cfg], inline: <<-SHELL
      sed -i 's|proxy = .*|# proxy = |' $1
      sed -i 's|force_tcp = .*|force_tcp = false|' $1
    SHELL
  end

  config.vm.provision "shell", name: "restarting dnscrypt-proxy service", inline: <<-SHELL
    service dnscrypt-proxy restart
  SHELL

  # set up the firewall options
  config.vm.provision "shell", name: "configure ufw", path: "./system/firewall.sh"

  config.vm.provision "shell", name: "configure logrotate", inline: <<-SHELL
    mkdir -p /var/log/dnsmasq
	chown dnsmasq:root /var/log/dnsmasq
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

  config.vm.provision "shell", run: "always", inline: <<-SHELL
    echo 'none' > /var/tmp/ip4
    echo 'none' > /var/tmp/ip6
  SHELL

  if settings.include? "ip4"
    config.vm.provision "shell", run: "always", args: settings["ip4"], inline: <<-SHELL
      echo $1 > /var/tmp/ip4
    SHELL
  end

  if settings.include? "ip6"
    config.vm.provision "shell", run: "always", args: settings["ip6"], inline: <<-SHELL
      echo $1 > /var/tmp/ip6
    SHELL
  end

  config.vm.provision "shell", run: "always", name: "download third party block lists", inline: <<-SHELL
    sh /valhalla/system/3rdparty.sh
  SHELL

  config.vm.provision "shell", name: "enable byobu at login for vagrant user", privileged: false, inline: <<-SHELL
    byobu-enable
  SHELL

  config.vm.provision "shell", run: "always", name: "finishing startup process", inline: <<-SHELL
    # link bashrc file in repo to one in profile
    cat /home/vagrant/.bashrc | grep valhalla || echo '. /valhalla/system/.bashrc' >> /home/vagrant/.bashrc
	
    # build rulesets
    php /valhalla/system/valhalla.php build

    # display banner message
    figlet valhalla
    echo '*'
    echo '* build complete!'
    echo '*'
    echo '* https://github.com/mmeyer2k/valhalla'
	echo '*'
	echo '* connect via SSH from host machine:'
	echo '* ssh -p 2288 vagrant@127.0.0.1'
    echo '*'
    echo '* host-only IPv4 DNS address: 127.0.0.1'
    echo '* host-only IPv6 DNS address: ::1'
    echo '*'
    echo '* public IPv4 DNS address: ' $(cat /var/tmp/ip4)
    echo '* public IPv6 DNS address: ' $(cat /var/tmp/ip6)
    echo '*'
    echo '* DNS server port: 53'
    echo '*'
  SHELL
end
