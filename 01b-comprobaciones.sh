#Comprobar si existe zona wan y tiene nat
uci show firewall | grep "=zone" -A4 | grep -A4 "name='wan'"
nft list chain inet fw4 zone_wan_postrouting | grep MASQUERADE
# (o iptables) iptables -t nat -L zone_wan_postrouting -v -n | grep MASQUERADE

# Está asociada a las redes correctas:
uci show firewall | grep "name='wan'" -A4 | grep network

# Hay forwardings desde tus VLAN a wan:
uci show firewall | grep "=forwarding" -A2 | grep -E "src='(lan10|infra20|iot30|family40|guest50|admin60)'.*dest='wan'"

# Salida a Internet OK (desde el router y desde Pi-hole):
ping -c2 1.1.1.1
# en el Pi-hole (o desde el router apuntando explícitamente):
dig @1.1.1.1 openwrt.org +short
