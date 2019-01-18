#!/bin/bash

# sets the firewall rules
# supports vpn killswitch option
#
# useage: firewall.sh [--vpn-lock]

# reset rules
yes | ufw reset

# set outbound rules
if [ "$1" = "--vpn-lock" ]; then
    ufw allow out on tun0 from any to any
    touch /var/tmp/vpnlock
else
    ufw default allow outgoing
    rm -f /var/tmp/vpnlock
fi

# set inbound rules
ufw default deny incoming
ufw allow 22
ufw allow 53
ufw allow 8888
ufw logging on

# re-enable the firewall
ufw enable