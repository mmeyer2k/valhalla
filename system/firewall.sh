#!/bin/bash

# make sure forwarding is allowed in the ufw config
sed -i 's|#net/ipv4/ip_forward=1|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf
sed -i 's|#net/ipv6/conf/default/forwarding=1|net/ipv6/conf/default/forwarding=1|' /etc/ufw/sysctl.conf
sed -i 's|#net/ipv6/conf/all/forwarding=1|net/ipv6/conf/all/forwarding=1|' /etc/ufw/sysctl.conf
sysctl -p

# configure ufw
ufw --force reset
ufw default allow outgoing
ufw default deny incoming
ufw allow 22
ufw allow 53
ufw logging off
ufw --force enable