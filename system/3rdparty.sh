#!/bin/bash

curl -fsSL https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt > /etc/dnsmasq.d/notracking
curl -fsSL https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt > /valhalla/hosts.d/notracking.hosts