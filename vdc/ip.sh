
PUBLIC_IP=10.158.14.6
PUBLIC_MASK=255.255.252.0
PUBLIC_GATEWAY=10.158.15.253

PRIATE_IP=10

# public ip
MAC=$(ifconfig |grep -E "eth0" -A3 |grep ether | sed "s#.*ether \([A-Fa-f0-9:]*\).*#\1#")
cat >/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=eth0
IPADDR=$PUBLIC_IP
NETMASK=$PUBLIC_MASK
GATEWAY=$PUBLIC_GATEWAY
HWADDR=$MAC
ONBOOT=yes
EOF

cat >/etc/resolv.conf <<EOF 
domain eng.vmware.com
search eng.vmware.com
nameserver 10.132.7.1
nameserver 10.132.7.2
EOF

#private ip
MAC=$(ifconfig |grep -E "eth1" -A3 |grep ether | sed "s#.*ether \([A-Fa-f0-9:]*\).*#\1#")
if [ -n "$MAC" ]; then
cat >/etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=eth1
IPADDR=192.168.80.$PRIATE_IP
NETMASK=255.255.255.0
HWADDR=$MAC
ONBOOT=yes
EOF
fi

#private ip
MAC=$(ifconfig |grep -E "eth2" -A3 |grep ether | sed "s#.*ether \([A-Fa-f0-9:]*\).*#\1#")
if [ -n "$MAC" ]; then
cat >/etc/sysconfig/network-scripts/ifcfg-eth2 <<EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=eth2
IPADDR=192.168.90.$PRIATE_IP
NETMASK=255.255.255.0
HWADDR=$MAC
ONBOOT=yes
EOF
fi

#private ip
MAC=$(ifconfig |grep -E "eth3" -A3 |grep ether | sed "s#.*ether \([A-Fa-f0-9:]*\).*#\1#")
if [ -n "$MAC" ]; then
cat >/etc/sysconfig/network-scripts/ifcfg-eth3 <<EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=eth3
IPADDR=192.168.70.$PRIATE_IP
NETMASK=255.255.255.0
HWADDR=$MAC
ONBOOT=yes
EOF
fi


