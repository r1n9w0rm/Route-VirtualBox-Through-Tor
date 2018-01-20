#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as sudo/root." 
   exit 1
fi
echo "This script will create a virtual interface and route all traffic going through it, through Tor."
read -p "Press enter to continue"
echo y | apt-get install bridge-utils
echo "# VirtualBox NAT bridge" >> /etc/network/interfaces
echo "auto vnet0" >> /etc/network/interfaces
echo "iface vnet0 inet static" >> /etc/network/interfaces
echo "What IP address would you like as the gateway for the Virtual Adapter (i.e. 192.168.1.2)?"
read ipaddr
echo "address " $ipaddr >> /etc/network/interfaces
echo "netmask 255.255.255.0" >> /etc/network/interfaces
echo "bridge_ports none" >> /etc/network/interfaces
echo "bridge_maxwait 0" >> /etc/network/interfaces
echo "bridge_fd 1" >> /etc/network/interfaces
echo What IP address would you like for post routing? (i.e. 192.168.1.0)?
read postroutipaddr
echo "up iptables -t nat -I POSTROUTING -s $postroutipaddr/24 -j MASQUERADE" >> /etc/network/interfaces
echo "down iptables -t nat -D POSTROUTING -s $postroutipaddr/24 -j MASQUERADE" >> /etc/network/interfaces
ip link delete vnet0
ifup vnet0
echo y | apt-get install dnsmasq
echo "interface=vnet0" >> /etc/dnsmasq.conf
echo "What IP address would you like to start at for the DHCP range (i.e. 192.168.1.3)?"
echo "dhcp-range=192.168.1.3,192.168.1.254,1h" >> /etc/dnsmasq.conf
service /etc/init.d/dnsmasq restart
echo y | apt-get install tor
echo "VirtualAddrNetwork 10.192.0.0/10" >> /etc/tor/torrc
echo "AutomapHostsOnResolve 1" >> /etc/tor/torrc
echo "TransPort $ipaddr:9040" >> /etc/tor/torrc
echo "DNSPort $ipaddr:53" >> /etc/tor/torrc
service tor restart
echo "What local ipaddress ranges would you like to avoid routing through tor (i.e. 10.8.0.0/10, x.x.x.x/x)?"
read nontor
echo "Flushing IP Tables..."
iptables -F
iptables -t nat -F
iptables -t nat -I POSTROUTING -s $postroutipaddr/24 -j MASQUERADE
for NET in $nontor; do
 iptables -t nat -A PREROUTING -i vnet0 -d $NET -j RETURN
done
iptables -t nat -A PREROUTING -i vnet0 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -A FORWARD -i vnet0 -p udp -j DROP
iptables -t nat -A PREROUTING -i vnet0 -p tcp --syn -j REDIRECT --to-ports 9040
echo "Finished :) Make sure all VirtualBox machines have their adapters set to Bridged Adapter - vnet0"
