#!/bin/bash
set -e
# Preload iptables,Rule lost when preventing restart of container!

# required for VPN connection:
iptables -t mangle -A FORWARD -s 10.28.0.0/24 -o eno1 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

# internet connectivity:
iptables -t nat -A POSTROUTING -s 10.28.0.0/24 -o eno1 -j MASQUERADE

# port forward:
iptables -t nat -A PREROUTING -p tcp --dport 40000 -j DNAT --to 10.28.0.80
iptables -t nat -A PREROUTING -p tcp --dport 40001 -j DNAT --to 10.28.0.80

# if [ -f /etc/sysconfig/iptables ]
# then
#   iptables-restore -n < /etc/sysconfig/iptables
# fi

# Repair gcp container restart, can not access google family bucket(Disable pmtu discovery!)
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.ip_no_pmtu_disc=1

# Setting eap-radius config info
if [ -z "$ACCOUNTING" ]; then
  export ACCOUNTING=no
fi

if [ -z "$RADIUS_PORT" ]; then
  export RADIUS_PORT=1812
fi

if [ -z "$RADIUS_SERVER" ]; then
  export RADIUS_SERVER=''
fi

if [ -z "$RADIUS_SECRET" ]; then
  export RADIUS_SECRET=''
fi

envsubst '
          ${ACCOUNTING}
          ${RADIUS_PORT}
          ${RADIUS_SERVER}
          ${RADIUS_SECRET}
         ' < eap-radius.conf.template > /usr/local/etc/strongswan.d/charon/eap-radius.conf

# Setting eap auth type
if [ -z "$EAP_TYPE" ]; then
  export EAP_TYPE='eap-mschapv2'
fi

if [ -z "$HOST_IP" ]; then
  export HOST_IP='0.0.0.0'
fi

envsubst '
         ${EAP_TYPE}
         ${HOST_IP}
         ' < ipsec.conf.template > /usr/local/etc/ipsec.conf

exec "$@"
