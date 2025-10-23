#!/bin/sh
# 01-config-inicial-luci.sh
set -e

# Función que borra sin romper el script si no existe la sección/opción
safe_del() { uci -q delete "$1" >/dev/null 2>&1 || true; }

ts=$(date +%F-%H%M%S)
cp -a /etc/config/network  /etc/config/network.bak.$ts
cp -a /etc/config/firewall /etc/config/firewall.bak.$ts
cp -a /etc/config/dhcp     /etc/config/dhcp.bak.$ts
[ -f /etc/config/uhttpd ]  && cp -a /etc/config/uhttpd  /etc/config/uhttpd.bak.$ts
[ -f /etc/config/dropbear ]&& cp -a /etc/config/dropbear /etc/config/dropbear.bak.$ts

echo "[1/5] NETWORK: aplicar bridge+VLANs+interfaces..."
safe_del network.br_lan
uci set network.br_lan='device'
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci set network.br_lan.stp='1'
uci set network.br_lan.vlan_filtering='1'
safe_del network.br_lan.ports
uci add_list network.br_lan.ports='lan1'
uci add_list network.br_lan.ports='lan2'
uci add_list network.br_lan.ports='lan3'
uci add_list network.br_lan.ports='lan4'
uci add_list network.br_lan.ports='lan5'

# BRIDGE-VLANs
for V in 10 20 30 40 50 60; do safe_del network.vlan$V; done
uci set network.vlan10='bridge-vlan'; uci set network.vlan10.device='br-lan'; uci set network.vlan10.vlan='10'
uci add_list network.vlan10.ports='lan1:t'; uci add_list network.vlan10.ports='lan2:u*'
uci set network.vlan20='bridge-vlan'; uci set network.vlan20.device='br-lan'; uci set network.vlan20.vlan='20'
uci add_list network.vlan20.ports='lan1:t'; uci add_list network.vlan20.ports='lan3:u*'
uci set network.vlan30='bridge-vlan'; uci set network.vlan30.device='br-lan'; uci set network.vlan30.vlan='30'
uci add_list network.vlan30.ports='lan1:t'; uci add_list network.vlan30.ports='lan4:u*'
uci set network.vlan40='bridge-vlan'; uci set network.vlan40.device='br-lan'; uci set network.vlan40.vlan='40'
uci add_list network.vlan40.ports='lan1:t'
uci set network.vlan50='bridge-vlan'; uci set network.vlan50.device='br-lan'; uci set network.vlan50.vlan='50'
uci add_list network.vlan50.ports='lan1:t'
uci set network.vlan60='bridge-vlan'; uci set network.vlan60.device='br-lan'; uci set network.vlan60.vlan='60'
uci add_list network.vlan60.ports='lan1:t'; uci add_list network.vlan60.ports='lan5:u*'

# Devices 802.1q (opcionales)
for n in v10work v20infra v30iot v40fam v50guest v60admin; do safe_del network.$n; done
uci set network.v10work='device';  uci set network.v10work.type='8021q'; uci set network.v10work.ifname='br-lan'; uci set network.v10work.vid='10'; uci set network.v10work.name='br-lan.10-work'
uci set network.v20infra='device'; uci set network.v20infra.type='8021q'; uci set network.v20infra.ifname='br-lan'; uci set network.v20infra.vid='20'; uci set network.v20infra.name='br-lan.20-infra'
uci set network.v30iot='device';   uci set network.v30iot.type='8021q';  uci set network.v30iot.ifname='br-lan';  uci set network.v30iot.vid='30'; uci set network.v30iot.name='br-lan.30-iot'
uci set network.v40fam='device';   uci set network.v40fam.type='8021q';  uci set network.v40fam.ifname='br-lan';  uci set network.v40fam.vid='40'; uci set network.v40fam.name='br-lan.40-fam'
uci set network.v50guest='device'; uci set network.v50guest.type='8021q';uci set network.v50guest.ifname='br-lan';uci set network.v50guest.vid='50'; uci set network.v50guest.name='br-lan.50-guest'
uci set network.v60admin='device'; uci set network.v60admin.type='8021q';uci set network.v60admin.ifname='br-lan';uci set network.v60admin.vid='60'; uci set network.v60admin.name='br-lan.60-admin'

# Interfaces L3
for i in lan10 serv20 iot30 family40 guest50 admin60; do safe_del network.$i; done
uci set network.lan10='interface';    uci set network.lan10.proto='static';    uci set network.lan10.device='br-lan.10-work';   uci set network.lan10.ipaddr='192.168.10.1'; uci set network.lan10.netmask='255.255.255.0'; uci set network.lan10.ip6assign='0'
uci set network.serv20='interface';   uci set network.serv20.proto='static';   uci set network.serv20.device='br-lan.20-infra';  uci set network.serv20.ipaddr='192.168.20.1'; uci set network.serv20.netmask='255.255.255.0'; uci set network.serv20.ip6assign='0'
uci set network.iot30='interface';    uci set network.iot30.proto='static';    uci set network.iot30.device='br-lan.30-iot';    uci set network.iot30.ipaddr='192.168.30.1'; uci set network.iot30.netmask='255.255.255.0'; uci set network.iot30.ip6assign='0'
uci set network.family40='interface'; uci set network.family40.proto='static'; uci set network.family40.device='br-lan.40-fam';  uci set network.family40.ipaddr='192.168.40.1'; uci set network.family40.netmask='255.255.255.0'; uci set network.family40.ip6assign='0'
uci set network.guest50='interface';  uci set network.guest50.proto='static';  uci set network.guest50.device='br-lan.50-guest'; uci set network.guest50.ipaddr='192.168.50.1'; uci set network.guest50.netmask='255.255.255.0'; uci set network.guest50.ip6assign='0'
uci set network.admin60='interface';  uci set network.admin60.proto='static';  uci set network.admin60.device='br-lan.60-admin'; uci set network.admin60.ipaddr='192.168.60.1'; uci set network.admin60.netmask='255.255.255.0'; uci set network.admin60.ip6assign='0'

# (opcional) suprime la LAN heredada si existe
safe_del network.lan

uci commit network

echo "[2/5] DHCP por VLAN..."
for s in lan10 serv20 iot30 family40 guest50 admin60; do safe_del dhcp.$s; done
uci set dhcp.lan10='dhcp';    uci set dhcp.lan10.interface='lan10';      uci set dhcp.lan10.start='100'; uci set dhcp.lan10.limit='150'; uci set dhcp.lan10.leasetime='12h'; uci set dhcp.lan10.ignore='0'; uci set dhcp.lan10.dhcpv6='disabled'; uci set dhcp.lan10.ra='disabled'
uci set dhcp.serv20='dhcp';   uci set dhcp.serv20.interface='serv20';    uci set dhcp.serv20.start='100'; uci set dhcp.serv20.limit='150'; uci set dhcp.serv20.leasetime='12h'; uci set dhcp.serv20.ignore='0'; uci set dhcp.serv20.dhcpv6='disabled'; uci set dhcp.serv20.ra='disabled'
uci set dhcp.iot30='dhcp';    uci set dhcp.iot30.interface='iot30';      uci set dhcp.iot30.start='100'; uci set dhcp.iot30.limit='150'; uci set dhcp.iot30.leasetime='12h'; uci set dhcp.iot30.ignore='0'; uci set dhcp.iot30.dhcpv6='disabled'; uci set dhcp.iot30.ra='disabled'
uci set dhcp.family40='dhcp'; uci set dhcp.family40.interface='family40'; uci set dhcp.family40.start='100'; uci set dhcp.family40.limit='150'; uci set dhcp.family40.leasetime='12h'; uci set dhcp.family40.ignore='0'; uci set dhcp.family40.dhcpv6='disabled'; uci set dhcp.family40.ra='disabled'
uci set dhcp.guest50='dhcp';  uci set dhcp.guest50.interface='guest50';  uci set dhcp.guest50.start='100'; uci set dhcp.guest50.limit='150'; uci set dhcp.guest50.leasetime='12h'; uci set dhcp.guest50.ignore='0'; uci set dhcp.guest50.dhcpv6='disabled'; uci set dhcp.guest50.ra='disabled'
uci set dhcp.admin60='dhcp';  uci set dhcp.admin60.interface='admin60';  uci set dhcp.admin60.start='100'; uci set dhcp.admin60.limit='150'; uci set dhcp.admin60.leasetime='12h'; uci set dhcp.admin60.ignore='0'; uci set dhcp.admin60.dhcpv6='disabled'; uci set dhcp.admin60.ra='disabled'
uci commit dhcp

echo "[3/5] FIREWALL: limpiar restos GL.iNet y crear zonas nuevas..."
# Elimina zonas heredadas molestas
for name in guest wgserver ovpnserver; do
  for idx in $(uci show firewall | grep "=.zone" | cut -d. -f3 | cut -d= -f1); do
    [ "$(uci -q get firewall.$idx.name)" = "$name" ] && safe_del firewall.$idx
  done
done
# Elimina secciones que referencian redes/zonas que no usaremos
for pat in 'wan6' 'wwan' 'secondwan' 'wgserver' 'ovpnserver' 'guest$' 'guest[^0-9]'; do
  for sec in $(uci show firewall | grep -E "$pat" | cut -d. -f3 | cut -d= -f1 | sort -u); do
    safe_del firewall.$sec
  done
done
# (opcional) borra zona 'lan' heredada si existe
for idx in $(uci show firewall | grep "=zone" | cut -d. -f3 | cut -d= -f1); do
  name=$(uci -q get firewall.$idx.name)
  [ "$name" = "lan" ] && safe_del firewall.$idx
done

# Zonas nuevas
for z in lan10 infra20 iot30 family40 guest50 admin60; do safe_del firewall.$z; done
uci set firewall.lan10='zone';    uci set firewall.lan10.name='lan10';    uci set firewall.lan10.input='ACCEPT'; uci set firewall.lan10.output='ACCEPT'; uci set firewall.lan10.forward='REJECT'; uci add_list firewall.lan10.network='lan10'
uci set firewall.infra20='zone';  uci set firewall.infra20.name='infra20'; uci set firewall.infra20.input='ACCEPT'; uci set firewall.infra20.output='ACCEPT'; uci set firewall.infra20.forward='REJECT'; uci add_list firewall.infra20.network='serv20'
uci set firewall.iot30='zone';    uci set firewall.iot30.name='iot30';    uci set firewall.iot30.input='REJECT'; uci set firewall.iot30.output='ACCEPT'; uci set firewall.iot30.forward='REJECT'; uci add_list firewall.iot30.network='iot30'
uci set firewall.family40='zone'; uci set firewall.family40.name='family40'; uci set firewall.family40.input='ACCEPT'; uci set firewall.family40.output='ACCEPT'; uci set firewall.family40.forward='REJECT'; uci add_list firewall.family40.network='family40'
uci set firewall.guest50='zone';  uci set firewall.guest50.name='guest50'; uci set firewall.guest50.input='REJECT'; uci set firewall.guest50.output='ACCEPT'; uci set firewall.guest50.forward='REJECT'; uci add_list firewall.guest50.network='guest50'
uci set firewall.admin60='zone';  uci set firewall.admin60.name='admin60'; uci set firewall.admin60.input='ACCEPT'; uci set firewall.admin60.output='ACCEPT'; uci set firewall.admin60.forward='REJECT'; uci add_list firewall.admin60.network='admin60'

# Forwardings
for f in f_lan10_infra20 f_lan10_iot30 f_lan10_family40 f_lan10_guest50 f_lan10_wan \
         f_infra20_lan10 f_infra20_wan \
         f_family40_wan f_guest50_wan f_iot30_wan \
         f_admin60_lan10 f_admin60_infra20 f_admin60_iot30 f_admin60_family40 f_admin60_guest50 f_admin60_wan; do
  safe_del firewall.$f
done
uci set firewall.f_lan10_infra20='forwarding'; uci set firewall.f_lan10_infra20.src='lan10';    uci set firewall.f_lan10_infra20.dest='infra20'
uci set firewall.f_lan10_iot30='forwarding';   uci set firewall.f_lan10_iot30.src='lan10';      uci set firewall.f_lan10_iot30.dest='iot30'
uci set firewall.f_lan10_family40='forwarding';uci set firewall.f_lan10_family40.src='lan10';   uci set firewall.f_lan10_family40.dest='family40'
uci set firewall.f_lan10_guest50='forwarding'; uci set firewall.f_lan10_guest50.src='lan10';    uci set firewall.f_lan10_guest50.dest='guest50'
uci set firewall.f_lan10_wan='forwarding';     uci set firewall.f_lan10_wan.src='lan10';        uci set firewall.f_lan10_wan.dest='wan'
uci set firewall.f_infra20_lan10='forwarding'; uci set firewall.f_infra20_lan10.src='infra20';  uci set firewall.f_infra20_lan10.dest='lan10'
uci set firewall.f_infra20_wan='forwarding';   uci set firewall.f_infra20_wan.src='infra20';    uci set firewall.f_infra20_wan.dest='wan'
uci set firewall.f_family40_wan='forwarding';  uci set firewall.f_family40_wan.src='family40';  uci set firewall.f_family40_wan.dest='wan'
uci set firewall.f_guest50_wan='forwarding';   uci set firewall.f_guest50_wan.src='guest50';    uci set firewall.f_guest50_wan.dest='wan'
uci set firewall.f_iot30_wan='forwarding';     uci set firewall.f_iot30_wan.src='iot30';        uci set firewall.f_iot30_wan.dest='wan'
uci set firewall.f_admin60_lan10='forwarding';    uci set firewall.f_admin60_lan10.src='admin60';   uci set firewall.f_admin60_lan10.dest='lan10'
uci set firewall.f_admin60_infra20='forwarding';  uci set firewall.f_admin60_infra20.src='admin60'; uci set firewall.f_admin60_infra20.dest='infra20'
uci set firewall.f_admin60_iot30='forwarding';    uci set firewall.f_admin60_iot30.src='admin60';   uci set firewall.f_admin60_iot30.dest='iot30'
uci set firewall.f_admin60_family40='forwarding'; uci set firewall.f_admin60_family40.src='admin60';uci set firewall.f_admin60_family40.dest='family40'
uci set firewall.f_admin60_guest50='forwarding';  uci set firewall.f_admin60_guest50.src='admin60'; uci set firewall.f_admin60_guest50.dest='guest50'
uci set firewall.f_admin60_wan='forwarding';      uci set firewall.f_admin60_wan.src='admin60';     uci set firewall.f_admin60_wan.dest='wan'

# Reglas DHCP/DNS necesarias
for r in r_iot30_dhcp r_iot30_dns r_guest50_dhcp r_guest50_dns; do safe_del firewall.$r; done
uci set firewall.r_iot30_dhcp='rule';  uci set firewall.r_iot30_dhcp.name='Allow-DHCP-iot30';  uci set firewall.r_iot30_dhcp.src='iot30';   uci set firewall.r_iot30_dhcp.proto='udp';     uci set firewall.r_iot30_dhcp.dest_port='67-68'; uci set firewall.r_iot30_dhcp.target='ACCEPT'
uci set firewall.r_iot30_dns='rule';   uci set firewall.r_iot30_dns.name='Allow-DNS-iot30';    uci set firewall.r_iot30_dns.src='iot30';    uci set firewall.r_iot30_dns.proto='tcp udp';  uci set firewall.r_iot30_dns.dest_port='53';     uci set firewall.r_iot30_dns.target='ACCEPT'
uci set firewall.r_guest50_dhcp='rule';uci set firewall.r_guest50_dhcp.name='Allow-DHCP-guest50'; uci set firewall.r_guest50_dhcp.src='guest50'; uci set firewall.r_guest50_dhcp.proto='udp'; uci set firewall.r_guest50_dhcp.dest_port='67-68'; uci set firewall.r_guest50_dhcp.target='ACCEPT'
uci set firewall.r_guest50_dns='rule'; uci set firewall.r_guest50_dns.name='Allow-DNS-guest50';   uci set firewall.r_guest50_dns.src='guest50';  uci set firewall.r_guest50_dns.proto='tcp udp'; uci set firewall.r_guest50_dns.dest_port='53';    uci set firewall.r_guest50_dns.target='ACCEPT'

uci commit firewall

echo "[4/5] REINICIOS en orden..."
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart