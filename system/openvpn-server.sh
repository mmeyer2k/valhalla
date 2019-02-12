#!/bin/bash

PORT=1194
IP='10.1.10.64'
RCLOCAL='/etc/rc.local'
OVPN=/valhalla/client.ovpn

# install openvpn server
apt-get install openvpn iptables openssl ca-certificates -y

# Get easy-rsa
curl -L 'https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.6/EasyRSA-unix-v3.0.6.tgz' 1> ~/easyrsa.tgz 2>/dev/null
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
EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full client nopass
EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
  
# Move the stuff we need
cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn
  
# CRL is read with each client connection, when OpenVPN is dropped to nobody
chown nobody:nogroup /etc/openvpn/crl.pem
  
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
proto udp
dev tun
sndbuf 0
rcvbuf 0
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
auth SHA512
tls-auth /etc/openvpn/ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp.txt" > /etc/openvpn/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS $IP\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS $IP\"" >> /etc/openvpn/server.conf
echo "keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
crl-verify /etc/openvpn/crl.pem" >> /etc/openvpn/server.conf

echo '#!/bin/sh -e
exit 0' > $RCLOCAL

# IP forwarding
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set NAT for the VPN subnet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP
sed -i "1 a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $IP" $RCLOCAL
if iptables -L -n | grep -qE '^(REJECT|DROP)'; then
	iptables -I INPUT -p udp --dport $PORT -j ACCEPT
	iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
	iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	sed -i "1 a\iptables -I INPUT -p udp --dport $PORT -j ACCEPT" $RCLOCAL
	sed -i "1 a\iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT" $RCLOCAL
	sed -i "1 a\iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" $RCLOCAL
fi

/etc/init.d/openvpn restart

echo "client
dev tun
proto udp
sndbuf 0
rcvbuf 0
remote $IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
setenv opt block-outside-dns
key-direction 1
verb 3" > /etc/openvpn/client-common.txt

# Generates the custom client.ovpn
cp /etc/openvpn/client-common.txt $OVPN
echo "<ca>" >> $OVPN
cat /etc/openvpn/easy-rsa/pki/ca.crt >>$OVPN
echo "</ca>" >> $OVPN
echo "<cert>" >> $OVPN
sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/easy-rsa/pki/issued/client.crt >> $OVPN
echo "</cert>" >> $OVPN
echo "<key>" >> $OVPN
cat /etc/openvpn/easy-rsa/pki/private/client.key >> $OVPN
echo "</key>" >> $OVPN
echo "<tls-auth>" >> $OVPN
sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/ta.key >> $OVPN
echo "</tls-auth>" >> $OVPN
