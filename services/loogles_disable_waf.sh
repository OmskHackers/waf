#!/bin/bash

iface=any
service_port=8087
waf_port=18087

iptables -D PREROUTING -t nat -i $iface -p tcp --dport $service_port -j REDIRECT --to-port $waf_port
