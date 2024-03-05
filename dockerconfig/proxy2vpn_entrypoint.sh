#!/bin/bash
# 改为如果不存在，则创建
pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/ca-key.pem
pki --self --ca --lifetime 3650 --in /etc/ipsec.d/private/ca-key.pem \
    --type rsa --dn "CN=VPN root CA" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem
pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/server-key.pem
pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa \
    | pki --issue --lifetime 1825 \
    --cacert /etc/ipsec.d/cacerts/ca-cert.pem \
    --cakey /etc/ipsec.d/private/ca-key.pem \
    --dn "CN=127.0.0.1" --san 127.0.0.1 --san @127.0.0.1 \
    --flag serverAuth --flag ikeIntermediate --outform pem \
    >  /etc/ipsec.d/certs/server-cert.pem

echo ': RSA "server-key.pem"' > /etc/ipsec.secrets
echo 'vpn_user : EAP "vpn_password"' >> /etc/ipsec.secrets

# clear existing route rules
iptables -F
iptables -X 
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
iptables -t mangle -F
iptables -t mangle -X
iptables -t mangle -Z

# define proxy usage for particular sites
iptables -t nat -N REDSOCKS

# particular site1 configuration, e.g. proxy should be used for 99.99.99.01/32
iptables -t nat -A REDSOCKS -p tcp -d 99.99.99.01/32 -j REDIRECT --to-ports 9978

# particular site2 configuration, e.g. proxy should be used for 99.99.99.02/32
iptables -t nat -A REDSOCKS -p tcp -d 99.99.99.02/32 -j REDIRECT --to-ports 9978

# no proxy by default
iptables -t nat -A REDSOCKS -p tcp -j RETURN

# enable redsocks
iptables -t nat -A PREROUTING -p tcp -j REDSOCKS
iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

# enable internet sharing for vpn clients
iptables -t nat -A POSTROUTING -s 10.10.10.10/24 -o eth0 -j MASQUERADE

# ensure tcp packets size not bigger than required max length
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.10/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

