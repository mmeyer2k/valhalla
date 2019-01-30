#!/bin/bash
#
# https://github.com/Nyr/openvpn-install
#
# Copyright (c) 2013 Nyr. Released under the MIT License.

# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit
fi

OS=debian
GROUPNAME=nogroup
RCLOCAL='/etc/rc.local'

newclient () {
	# Generates the custom client.ovpn
	cp /etc/openvpn/client-common.txt ~/$1.ovpn
	echo "<ca>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/ca.crt >> ~/$1.ovpn
	echo "</ca>" >> ~/$1.ovpn
	echo "<cert>" >> ~/$1.ovpn
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/easy-rsa/pki/issued/$1.crt >> ~/$1.ovpn
	echo "</cert>" >> ~/$1.ovpn
	echo "<key>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/private/$1.key >> ~/$1.ovpn
	echo "</key>" >> ~/$1.ovpn
	echo "<tls-auth>" >> ~/$1.ovpn
	sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/ta.key >> ~/$1.ovpn
	echo "</tls-auth>" >> ~/$1.ovpn
}


IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
read -p "IP address: " -e -i $IP IP
  
# If $IP is a private IP address, the server must be behind NAT
if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
  echo "This server is behind NAT. What is the public IPv4 address or hostname?"
  read -p "Public IP address / hostname: " -e PUBLICIP
fi

# install openvpn server
apt-get update
apt-get install openvpn iptables openssl ca-certificates -y

# Get easy-rsa
EASYRSAURL='https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.5/EasyRSA-nix-3.0.5.tgz'
wget -O ~/easyrsa.tgz "$EASYRSAURL" 2>/dev/null || curl -Lo ~/easyrsa.tgz "$EASYRSAURL"
tar xzf ~/easyrsa.tgz -C ~/
mv ~/EasyRSA-3.0.5/ /etc/openvpn/
mv /etc/openvpn/EasyRSA-3.0.5/ /etc/openvpn/easy-rsa/
chown -R root:root /etc/openvpn/easy-rsa/
rm -f ~/easyrsa.tgz
cd /etc/openvpn/easy-rsa/
  
# Create the PKI, set up the CA and the server and client certificates
./easyrsa init-pki
./easyrsa --batch build-ca nopass
EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass
EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full $CLIENT nopass
EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
  
# Move the stuff we need
cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn
  
# CRL is read with each client connection, when OpenVPN is dropped to nobody
chown nobody:$GROUPNAME /etc/openvpn/crl.pem
  
# Generate key for tls-auth
openvpn --genkey --secret /etc/openvpn/ta.key
  
# Create the DH parameters file using the predefined ffdhe2048 group
echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----' > /etc/openvpn/dh.pem

# Create server.conf
echo "port $PORT
proto $PROTOCOL
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" > /etc/openvpn/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf
echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server.conf
echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server.conf
echo "keepalive 10 120
cipher AES-256-CBC
user nobody
group $GROUPNAME
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify crl.pem" >> /etc/openvpn/server.conf
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf
echo 1 > /proc/sys/net/ipv4/ip_forward

# Needed to use rc.local with some systemd distros
if [[ "$OS" = 'debian' && ! -e $RCLOCAL ]]; then
  echo '#!/bin/sh -e
exit 0' > $RCLOCAL
fi
chmod +x $RCLOCAL

# Set NAT for the VPN subnet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP
sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP" $RCLOCAL
if iptables -L -n | grep -qE '^(REJECT|DROP)'; then
  # If iptables has at least one REJECT rule, we asume this is needed.
  # Not the best approach but I can't think of other and this shouldn't
  # cause problems.
  iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
  iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
  iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
  sed -i "1 a\iptables -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT" $RCLOCAL
  sed -i "1 a\iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT" $RCLOCAL
  sed -i "1 a\iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" $RCLOCAL
fi

/etc/init.d/openvpn restart

# If the server is behind a NAT, use the correct IP address
if [[ "$PUBLICIP" != "" ]]; then
  IP=$PUBLICIP
fi

# Generates the custom client.ovpn
newclient "$CLIENT"
echo "Your client configuration is available at:" ~/"$CLIENT.ovpn"
