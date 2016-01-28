
# Ref: https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7

# install openvpn and rss key tools
yum install epel-release -y
yum install expect openvpn easy-rsa -y

# initialize, changes in /etc/openvpn/server.conf is at end of this doc
cp /usr/share/doc/openvpn-*/sample/sample-config-files/server.conf /etc/openvpn
sed -i "s/server 10.8.0.0 255.255.255.0/#server 10.8.0.0 255.255.255.0/" /etc/openvpn/server.conf
cat >>/etc/openvpn/server.conf <<EOF
server 172.20.0.0 255.255.0.0
push "route 192.168.90.0 255.255.255.0"
push "route 192.168.80.0 255.255.255.0"
push "route 100.64.0.0 255.255.0.0"
EOF

rm -rf /etc/openvpn/easy-rsa/keys
mkdir -p /etc/openvpn/easy-rsa/keys
cp -rf /usr/share/easy-rsa/2.0/* /etc/openvpn/easy-rsa
sed -i "s#export KEY_NAME=.*#export KEY_NAME=\"server\"#"g /etc/openvpn/easy-rsa/vars

cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf


# create keys
cat >/tmp/auto.expect <<'EOF'
spawn {*}$argv
expect {
"y/n]" {
  send "y\r"
  exp_continue
}
"]:" {
  send "\r"
  exp_continue  
}
}
EOF

cd /etc/openvpn/easy-rsa
source ./vars

./clean-all
expect /tmp/auto.expect ./build-ca
expect /tmp/auto.expect ./build-key-server server
./build-dh
expect /tmp/auto.expect ./build-key client

# copy server keys
cd /etc/openvpn/easy-rsa/keys
cp dh2048.pem ca.crt server.crt server.key /etc/openvpn

# config route info
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -d 192.168.80.0/24 -o eth1 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -d 192.168.90.0/24 -o eth2 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -d 100.64.0.0/16 -o eth2 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -o eth0  -j MASQUERADE
iptables-save > /etc/sysconfig/iptables


# start openvpn
systemctl -f enable openvpn@server.service
systemctl start openvpn@server.service

 
# create client config, copy all the files under /etc/openvpn/client and import client.ovpn in your openvpn client
mkdir -p /etc/openvpn/client
cp ca.crt client.crt client.key /etc/openvpn/client


ETH0_IP=$(ifconfig |grep -E "eth0" -A3 |grep "inet " | sed "s#\s*inet \([0-9.]*\).*#\1#")
cd /etc/openvpn/client
cat >client.ovpn <<EOF
client 
dev tun 
proto udp 
remote ${ETH0_IP} 1194 
resolv-retry infinite 
nobind 
persist-key 
persist-tun 
comp-lzo 
verb 3 
ca ca.crt 
cert client.crt 
key client.key
EOF

