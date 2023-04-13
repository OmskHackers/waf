#!/bin/bash

#enp7s0
iface=enp7s0
service_port=8087
waf_port=18087

iptables -I PREROUTING 1 -t nat -i $iface -p tcp --dport $service_port -j REDIRECT --to-port $waf_port
