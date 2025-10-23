#!/bin/bash
# 02-aplicar-zero-trust-gestion.sh

set -e
echo "[5/5] Zero-trust en servicios de gestión..."
if [ -f /etc/init.d/uhttpd ]; then
  uci set uhttpd.main.listen_http='192.168.60.1:80'
  uci set uhttpd.main.listen_https='192.168.60.1:443'
  uci commit uhttpd
  /etc/init.d/uhttpd restart || true
fi
if [ -f /etc/init.d/dropbear ]; then
  uci set dropbear.@dropbear[0].Interface='admin60'
  uci commit dropbear
  /etc/init.d/dropbear restart || true
fi

echo "OK. Verificación rápida:"
bridge vlan show
ip -4 addr show dev br-lan
uci show firewall | grep -E "name='(lan10|infra20|iot30|family40|guest50|admin60)'"