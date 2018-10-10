#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as sudo/root." 
   exit 1
fi
echo "This script will route all traffic from VirtualBox through Tor."
read -p "Press enter to continue"

echo y | apt-get install tor
echo "AutomapHostsOnResolve 1" >> /etc/tor/torrc
echo "What is the gateway tor will be routed through? i.e. 192.168.1.2"
read GATEWAY
vboxmanage hostonlyif create
echo "What is the interface name for VirtualBox? i.e. vboxnet0"
read INTERFACENAME
vboxmanage hostonlyif ipconfig $INTERFACENAME --ip $GATEWAY
echo "TransPort $GATEWAY:9050" >> /etc/tor/torrc
echo "DNSPort $GATEWAY:1053" >> /etc/tor/torrc
echo "What exit nodes would you like for tor? Example: {US},{GB}"
read EXIT_NODES
echo "ExitNodes "$EXIT_NODES >> /etc/tor/torrc
echo "Flushing IP Tables..."
iptables -F
iptables -t nat -F
echo "Creating IP Tables rules..."
iptables -t nat -A PREROUTING ! -d $GATEWAY/32 -i vboxnet0 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9050
iptables -t nat -A PREROUTING ! -d $GATEWAY/32 -i vboxnet0 -p udp -m udp --dport 53 -j REDIRECT --to-ports 1053
echo "Restarting tor..."
service tor restart
sed -i '3d' /etc/resolv.conf
echo "What DNS would you like set in /etc/resolv.conf? i.e. 8.8.8.8"
read NEWDNS
echo "nameserver $NEWDNS" >> /etc/resolv.conf
echo "Finished :) Make sure all VirtualBox machines have their adapters set to Host Only Adapter - vboxnet0"
