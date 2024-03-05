#!/bin/bash
set -x

if [ ! $DOMAIN ]; then
    DOMAIN=127.0.0.1
fi

if [[ $DOMAIN =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
    SANIP="--san @$DOMAIN"
    LEFTID=$DOMAIN
else
    SANIP=""
    LEFTID=@$DOMAIN
fi

if [ ! -f /etc/ipsec.d/private/ca-key.pem ] || \
    [ ! -f /etc/ipsec.d/cacerts/ca-cert.pem ] || \
    [ ! -f /etc/ipsec.d/private/server-key.pem ] || \
    [ ! -f /etc/ipsec.d/certs/server-cert.pem ]; then
    pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/ca-key.pem
    pki --self --ca --lifetime 3650 --in /etc/ipsec.d/private/ca-key.pem \
        --type rsa --dn "CN=VPN root CA" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem
    pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/server-key.pem
    pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa \
        | pki --issue --lifetime 1825 \
        --cacert /etc/ipsec.d/cacerts/ca-cert.pem \
        --cakey /etc/ipsec.d/private/ca-key.pem \
        --dn "CN=$DOMAIN" --san $DOMAIN $SANIP \
        --flag serverAuth --flag ikeIntermediate --outform pem \
        >  /etc/ipsec.d/certs/server-cert.pem
fi

if [ ! -f /etc/ipsec.conf ] && [ -f /.dockerconfig/ipsec.conf ]; then
    cp /.dockerconfig/ipsec.conf /etc/ipsec.conf
    sed -i "s/\$LEFTID/$LEFTID/" /etc/ipsec.conf
fi

if [ ! -f /etc/ipsec.secrets ] && [ -f /.dockerconfig/ipsec.secrets ]; then
    cp /.dockerconfig/ipsec.secrets /etc/ipsec.secrets
fi

if [ -f /.dockerconfig/iptables_config.sh ]; then
    /bin/bash /.dockerconfig/iptables_config.sh
fi

systemctl restart strongswan-starter

set -ex
exec "$@"