#!/bin/bash

# sets the firewall rules
# supports vpn killswitch option
#
# useage: firewall.sh [--vpn-lock]

# make sure forwarding is allowed in the ufw config
sed -i 's|#net/ipv4/ip_forward=1|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf
sed -i 's|#net/ipv6/conf/default/forwarding=1|net/ipv6/conf/default/forwarding=1|' /etc/ufw/sysctl.conf
sed -i 's|#net/ipv6/conf/all/forwarding=1|net/ipv6/conf/all/forwarding=1|' /etc/ufw/sysctl.conf
sysctl -p

# reset rules
ufw --force reset

# set inbound rules
ufw default deny incoming
ufw allow 22
ufw allow 80

# enable logs
ufw logging on

# re-enable the firewall
ufw --force enable
