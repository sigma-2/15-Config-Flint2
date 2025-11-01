#!/bin/ash

set -e

# Función que borra sin romper el script si no existe la sección/opción
safe_del() { uci -q delete "$1" >/dev/null 2>&1 || true; }

ts=$(date +%F-%H%M%S)
cp -a /etc/config/network  /etc/config/network.bak.$ts
cp -a /etc/config/firewall /etc/config/firewall.bak.$ts
cp -a /etc/config/dhcp     /etc/config/dhcp.bak.$ts
[ -f /etc/config/uhttpd ]  && cp -a /etc/config/uhttpd  /etc/config/uhttpd.bak.$ts
[ -f /etc/config/dropbear ]&& cp -a /etc/config/dropbear /etc/config/dropbear.bak.$ts

#################################
# CREAMOS EL BRIDGE Y LOS VLANS #
#################################
echo "[1/..] NETWORK: aplicar bridge+VLANs+interfaces..."
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

# BRIDGE-VLANs Y MAPEOS EN EL ROUTER
for V in 10 20 30 40 50 60; do safe_del network.vlan$V; done

uci set network.vlan10='bridge-vlan'
uci set network.vlan10.device='br-lan'
uci set network.vlan10.vlan='10'
uci add_list network.vlan10.ports='lan1:t'
uci add_list network.vlan10.ports='lan2:u*'

uci set network.vlan20='bridge-vlan'
uci set network.vlan20.device='br-lan'
uci set network.vlan20.vlan='20'
uci add_list network.vlan20.ports='lan1:t'
uci add_list network.vlan20.ports='lan3:u*'

uci set network.vlan30='bridge-vlan'
uci set network.vlan30.device='br-lan'
uci set network.vlan30.vlan='30'
uci add_list network.vlan30.ports='lan1:t'
uci add_list network.vlan30.ports='lan4:u*'

uci set network.vlan40='bridge-vlan'
uci set network.vlan40.device='br-lan'
uci set network.vlan40.vlan='40'
uci add_list network.vlan40.ports='lan1:t'

uci set network.vlan50='bridge-vlan'
uci set network.vlan50.device='br-lan'
uci set network.vlan50.vlan='50'
uci add_list network.vlan50.ports='lan1:t'

uci set network.vlan60='bridge-vlan'
uci set network.vlan60.device='br-lan'
uci set network.vlan60.vlan='60'
uci add_list network.vlan60.ports='lan1:t'
uci add_list network.vlan60.ports='lan5:u*'

# Interfaces L3
for i in lan10 infra20 iot30 family40 guest50 admin60; do safe_del network.$i; done

uci set network.lan10='interface'
uci set network.lan10.proto='static'
uci set network.lan10.device='br-lan.10'
uci set network.lan10.ipaddr='192.168.10.1'
uci set network.lan10.netmask='255.255.255.0'
uci set network.lan10.ip6assign='0'

uci set network.infra20='interface'
uci set network.infra20.proto='static'
uci set network.infra20.device='br-lan.20'
uci set network.infra20.ipaddr='192.168.20.1'
uci set network.infra20.netmask='255.255.255.0'
uci set network.infra20.ip6assign='0'

uci set network.iot30='interface'
uci set network.iot30.proto='static'
uci set network.iot30.device='br-lan.30'
uci set network.iot30.ipaddr='192.168.30.1'
uci set network.iot30.netmask='255.255.255.0'
uci set network.iot30.ip6assign='0'

uci set network.family40='interface'
uci set network.family40.proto='static'
uci set network.family40.device='br-lan.40'
uci set network.family40.ipaddr='192.168.40.1'
uci set network.family40.netmask='255.255.255.0'
uci set network.family40.ip6assign='0'

uci set network.guest50='interface'
uci set network.guest50.proto='static'
uci set network.guest50.device='br-lan.50'
uci set network.guest50.ipaddr='192.168.50.1'
uci set network.guest50.netmask='255.255.255.0'
uci set network.guest50.ip6assign='0'

uci set network.admin60='interface'
uci set network.admin60.proto='static'
uci set network.admin60.device='br-lan.60'
uci set network.admin60.ipaddr='192.168.60.1'
uci set network.admin60.netmask='255.255.255.0'
uci set network.admin60.ip6assign='0'


# (opcional) suprime la LAN heredada si existe
safe_del network.lan

echo "[2/..] COMMIT NETWORK..."
uci commit network

#################################
# DHCP POR VLAN                #
#################################

echo "[3/..] DHCP por VLAN..."
for s in lan10 infra20 iot30 family40 guest50 admin60; do safe_del dhcp.$s; done

uci set dhcp.lan10='dhcp'
uci set dhcp.lan10.interface='lan10'
uci set dhcp.lan10.start='100'
uci set dhcp.lan10.limit='150'
uci set dhcp.lan10.leasetime='12h'
uci set dhcp.lan10.ignore='0'
uci set dhcp.lan10.dhcpv6='disabled'
uci set dhcp.lan10.ra='disabled'
uci add_list dhcp.lan10.option='6,192.168.20.2'


uci set dhcp.infra20='dhcp'
uci set dhcp.infra20.interface='infra20'
uci set dhcp.infra20.start='100'
uci set dhcp.infra20.limit='150'
uci set dhcp.infra20.leasetime='12h'
uci set dhcp.infra20.ignore='0'
uci set dhcp.infra20.dhcpv6='disabled'
uci set dhcp.infra20.ra='disabled'
uci add_list dhcp.infra20.option='6,192.168.20.2'

uci set dhcp.iot30='dhcp'
uci set dhcp.iot30.interface='iot30'
uci set dhcp.iot30.start='100'
uci set dhcp.iot30.limit='150'
uci set dhcp.iot30.leasetime='12h'
uci set dhcp.iot30.ignore='0'
uci set dhcp.iot30.dhcpv6='disabled'
uci set dhcp.iot30.ra='disabled'
uci add_list dhcp.iot30.option='6,192.168.20.2'

uci set dhcp.family40='dhcp'
uci set dhcp.family40.interface='family40'
uci set dhcp.family40.start='100'
uci set dhcp.family40.limit='150'
uci set dhcp.family40.leasetime='12h'
uci set dhcp.family40.ignore='0'
uci set dhcp.family40.dhcpv6='disabled'
uci set dhcp.family40.ra='disabled'
uci add_list dhcp.family40.option='6,192.168.20.2'

uci set dhcp.guest50='dhcp'
uci set dhcp.guest50.interface='guest50'
uci set dhcp.guest50.start='100'
uci set dhcp.guest50.limit='150'
uci set dhcp.guest50.leasetime='12h'
uci set dhcp.guest50.ignore='0'
uci set dhcp.guest50.dhcpv6='disabled'
uci set dhcp.guest50.ra='disabled'
uci add_list dhcp.guest50.option='6,192.168.20.2'

uci set dhcp.admin60='dhcp'
uci set dhcp.admin60.interface='admin60'
uci set dhcp.admin60.start='100'
uci set dhcp.admin60.limit='150'
uci set dhcp.admin60.leasetime='12h'
uci set dhcp.admin60.ignore='0'
uci set dhcp.admin60.dhcpv6='disabled'
uci set dhcp.admin60.ra='disabled'
uci add_list dhcp.admin60.option='6,192.168.20.2'


# --- Reservas DHCP (static leases) ---
# Colocar este bloque tras crear las secciones dhcp.<vlan> y ANTES de 'uci commit dhcp'

echo "[4/..] STATIC LEASES..."
# Limpieza idempotente (por nombre de sección)
for s in host_gs308t host_raspberry host_truenas host_ds918_lan1 host_ds918_lan2 host_n2ha; do
  safe_del dhcp.$s
done

# GS308T (admin60)
uci set dhcp.host_gs308t='host'
uci set dhcp.host_gs308t.name='Netgear-GS308T.switch'
uci set dhcp.host_gs308t.mac='80:CC:9C:9A:9E:85'
uci set dhcp.host_gs308t.ip='192.168.60.2'
uci set dhcp.host_gs308t.leasetime='infinite'

# Raspberry Pi-hole (infra20)
uci set dhcp.host_raspberry='host'
uci set dhcp.host_raspberry.name='Raspberry'
uci set dhcp.host_raspberry.mac='B8:27:EB:43:8B:7F'
uci set dhcp.host_raspberry.ip='192.168.20.2'
uci set dhcp.host_raspberry.leasetime='infinite'

# TrueNAS (infra20)
uci set dhcp.host_truenas='host'
uci set dhcp.host_truenas.name='TrueNAS'
uci set dhcp.host_truenas.mac='00:D8:61:C1:74:A8'
uci set dhcp.host_truenas.ip='192.168.20.3'
uci set dhcp.host_truenas.leasetime='infinite'

# DS918+ LAN1 (infra20)
uci set dhcp.host_ds918_lan1='host'
uci set dhcp.host_ds918_lan1.name='DS918-LAN1'
uci set dhcp.host_ds918_lan1.mac='00:11:32:7E:D6:73'
uci set dhcp.host_ds918_lan1.ip='192.168.20.4'
uci set dhcp.host_ds918_lan1.leasetime='infinite'

# DS918+ LAN2 (infra20)
uci set dhcp.host_ds918_lan2='host'
uci set dhcp.host_ds918_lan2.name='DS918-LAN2'
uci set dhcp.host_ds918_lan2.mac='00:11:32:7E:D6:74'
uci set dhcp.host_ds918_lan2.ip='192.168.20.5'
uci set dhcp.host_ds918_lan2.leasetime='infinite'

# N2+ Home Assistant (iot30)
uci set dhcp.host_n2ha='host'
uci set dhcp.host_n2ha.name='N2-HA'
uci set dhcp.host_n2ha.mac='00:1E:06:42:6A:34'
uci set dhcp.host_n2ha.ip='192.168.30.2'
uci set dhcp.host_n2ha.leasetime='infinite'

echo "[5/..] COMMIT DHCP..."
uci commit dhcp


#################################
# FIREWALL                      #
#################################

echo "[6/..] FIREWALL: limpiar restos GL.iNet y crear zonas nuevas..."
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
echo "[7/..] FIREWALL: ZONAS NUEVAS..."
for z in lan10 infra20 iot30 family40 guest50 admin60; do safe_del firewall.$z; done

uci set firewall.lan10='zone'
uci set firewall.lan10.name='lan10'
uci set firewall.lan10.input='REJECT'
uci set firewall.lan10.output='ACCEPT'
uci set firewall.lan10.forward='REJECT'
uci add_list firewall.lan10.network='lan10'

uci set firewall.infra20='zone'
uci set firewall.infra20.name='infra20'
uci set firewall.infra20.input='REJECT'
uci set firewall.infra20.output='ACCEPT'
uci set firewall.infra20.forward='REJECT'
uci add_list firewall.infra20.network='infra20'

uci set firewall.iot30='zone'
uci set firewall.iot30.name='iot30'
uci set firewall.iot30.input='DROP'
uci set firewall.iot30.output='ACCEPT'
uci set firewall.iot30.forward='DROP'
uci add_list firewall.iot30.network='iot30'

uci set firewall.family40='zone'
uci set firewall.family40.name='family40'
uci set firewall.family40.input='DROP'
uci set firewall.family40.output='ACCEPT'
uci set firewall.family40.forward='REJECT'
uci add_list firewall.family40.network='family40'

uci set firewall.guest50='zone'
uci set firewall.guest50.name='guest50'
uci set firewall.guest50.input='DROP'
uci set firewall.guest50.output='ACCEPT'
uci set firewall.guest50.forward='DROP'
uci add_list firewall.guest50.network='guest50'

uci set firewall.admin60='zone'
uci set firewall.admin60.name='admin60'
uci set firewall.admin60.input='ACCEPT'
uci set firewall.admin60.output='ACCEPT'
uci set firewall.admin60.forward='REJECT'
uci add_list firewall.admin60.network='admin60'

# --- Asegurar zona WAN presente y con NAT ---
# Crea la zona 'wan' si no existe todavía
echo "[8/..] FIREWALL: ZONAS NUEVAS - WAN..."
if ! uci show firewall | grep -q "=.zone" -A1 | grep -q "name='wan'"; then
  uci add firewall zone
  uci set firewall.@zone[-1].name='wan'
  uci set firewall.@zone[-1].input='DROP'
  uci set firewall.@zone[-1].output='ACCEPT'
  uci set firewall.@zone[-1].forward='DROP'
  uci set firewall.@zone[-1].masq='1'
  uci set firewall.@zone[-1].mtu_fix='1'
  uci add_list firewall.@zone[-1].network='wan'
  uci -q get network.wan6 && uci add_list firewall.@zone[-1].network='wan6'
fi

# Activa NAT/MTU fix en la zona 'wan' (sea cual sea su índice)
#uci show firewall | awk -F'[.=]' '/=zone$/{sec=$3} /\.name=.wan$/{print sec}' \
#| while read Z; do
#    uci set firewall.@zone[$Z].masq='1'
#    uci set firewall.@zone[$Z].mtu_fix='1'
#    # Asocia las redes 'wan' / 'wan6' si existen en /etc/config/network
#    uci -q get network.wan.proto  >/dev/null && uci add_list firewall.@zone[$Z].network='wan'
#    uci -q get network.wan6.proto >/dev/null && uci add_list firewall.@zone[$Z].network='wan6'
#  done

############################################################################
# ALLOW WAN
############################################################################
echo "[9/..] FIREWALL: PERMITIR WAN..."
# Reglas de acceso a WAN, más laxas para  10, 20, 40 y 60.
# Más estrictas para 30 y 50

# Comprueba si existe un forwarding src->dest (para evitar duplicados)
has_forwarding() {
  local SRC="$1" DEST="$2"
  # Busca secciones =forwarding con esos src/dest exactos
  uci show firewall | awk -F'[.=]' '
    $0 ~ /=forwarding$/ { sec=$3; src=""; dst=""; }
    $0 ~ /\.src=/        { if (sec!="") src=$0; gsub(/^.*'\''|'\''.*$/,"",src); src=src }
    $0 ~ /\.dest=/       { if (sec!="") dst=$0; gsub(/^.*'\''|'\''.*$/,"",dst); dst=dst
                           if (src=="'"$SRC"'" && dst=="'"$DEST"'") { print "HIT"; exit } }
  ' | grep -q HIT
}

# Crea un forwarding sólo si no existe ya el par src->dest
ensure_forwarding() {
  local NAME="$1" SRC="$2" DEST="$3"
  if has_forwarding "$SRC" "$DEST"; then
    echo "Forwarding $SRC → $DEST ya existe; no se duplica."
  else
    echo "Creando forwarding $SRC → $DEST ($NAME)..."
    safe_del firewall."$NAME"
    uci set firewall."$NAME"='forwarding'
    uci set firewall."$NAME".src="$SRC"
    uci set firewall."$NAME".dest="$DEST"
  fi
}

allow_wan_generic() {
  # ensure_forwarding f_lan10_wan   'lan10'   'wan' #->moved to strict
  # ensure_forwarding f_infra20_wan 'infra20' 'wan' #->moved to strict
  ensure_forwarding f_admin60_wan  'admin60' 'wan'
}

allow_wan_generic

allow_https() {
  local NAME=$1 SRC=$2
  uci set firewall."$NAME"='rule'
  uci set firewall."$NAME".name="$SRC-to-Internet-HTTP[S]"
  uci set firewall."$NAME".src="$SRC"
  uci set firewall."$NAME".dest='wan'
  uci set firewall."$NAME".proto='tcp'
  uci set firewall."$NAME".dest_port='80 443'
  uci set firewall."$NAME".target='ACCEPT'
}

allow_ntp() {
  local NAME=$1 SRC=$2
  uci set firewall."$NAME"='rule'
  uci set firewall."$NAME".name="$SRC-to-Internet-NTP"
  uci set firewall."$NAME".src="$SRC"
  uci set firewall."$NAME".dest='wan'
  uci set firewall."$NAME".proto='udp'
  uci set firewall."$NAME".dest_port='123'
  uci set firewall."$NAME".target='ACCEPT'
}


allow_wan_strict() {
  # https
  for r in allow_strict_lan10_https allow_strict_infra20_https allow_strict_iot30_https allow_strict_family40_https allow_strict_guest50_https; do safe_del firewall.$r; done
  allow_https allow_strict_lan10_https 'lan10'
  allow_https allow_strict_infra20_https 'infra20'
  allow_https allow_strict_iot30_https 'iot30'
  allow_https allow_strict_family40_https 'family40'
  allow_https allow_strict_guest50_https 'guest50'
  # ntp
  for r in allow_strict_lan10_ntp allow_strict_infra20_ntp allow_strict_iot30_ntp allow_strict_family40_ntp allow_strict_guest50_ntp; do safe_del firewall.$r; done
  allow_ntp allow_strict_lan10_ntp 'lan10'
  allow_ntp allow_strict_infra20_ntp 'infra20'
  allow_ntp allow_strict_iot30_ntp 'iot30'
  allow_ntp allow_strict_family40_ntp 'family40'
  allow_ntp allow_strict_guest50_ntp 'guest50'
}

# Activa las reglas estrictas para iot30/guest50
allow_wan_strict

# Permitir renovación DHCP en la WAN (IPv4)
safe_del firewall.wan_dhcp_renew
uci set firewall.wan_dhcp_renew='rule'
uci set firewall.wan_dhcp_renew.name='Allow-DHCP-Renew-WAN'
uci set firewall.wan_dhcp_renew.src='wan'
uci set firewall.wan_dhcp_renew.family='ipv4'
uci set firewall.wan_dhcp_renew.proto='udp'
uci set firewall.wan_dhcp_renew.dest_port='68'
uci set firewall.wan_dhcp_renew.target='ACCEPT'


############################################################################
# REGLAS DHCP
############################################################################

echo "[10/..] FIREWALL: PERMITIR DHCP..."
# Reglas DHCP necesarias. Definir después de las zonas. Permiten las solicitudes
for r in allow_lan10_dhcp allow_infra20_dhcp allow_iot30_dhcp allow_family40_dhcp allow_guest50_dhcp allow_admin60_dhcp; do safe_del firewall.$r; done

allow_dhcp() {
  local NAME=$1 SRC=$2
  uci set firewall."$NAME"='rule'
  uci set firewall."$NAME".name="Allow-DHCP-$SRC"
  uci set firewall."$NAME".family='ipv4'
  uci set firewall."$NAME".src="$SRC"
  uci set firewall."$NAME".proto='udp'
  uci set firewall."$NAME".src_port='68'
  uci set firewall."$NAME".dest_port='67'
  uci set firewall."$NAME".target='ACCEPT'
}

allow_dhcp allow_lan10_dhcp 'lan10'
allow_dhcp allow_infra20_dhcp 'infra20'
allow_dhcp allow_iot30_dhcp 'iot30'
allow_dhcp allow_family40_dhcp 'family40'
allow_dhcp allow_guest50_dhcp 'guest50'
allow_dhcp allow_admin60_dhcp 'admin60'


############################################################################
# REGLAS DNS
############################################################################

echo "[11/..] FIREWALL: PERMITIR DNS..."
# Permitir las peticiones DNS de cualquier zona al pihole
for r in allow_lan10_dns allow_infra20_dns allow_iot30_dns allow_family40_dns allow_guest50_dns allow_admin60_dns; do safe_del firewall.$r; done

allow_dns() {
  local NAME=$1 SRC=$2
  uci set firewall."$NAME"='rule'
  uci set firewall."$NAME".name="Allow-DNS-$SRC-to-PiHole"
  uci set firewall."$NAME".src="$SRC"
  uci set firewall."$NAME".dest="infra20"
  uci set firewall."$NAME".proto='tcp udp'
  uci set firewall."$NAME".dest_ip='192.168.20.2'
  uci set firewall."$NAME".dest_port='53'
  uci set firewall."$NAME".target='ACCEPT'
}

allow_dns allow_lan10_dns   'lan10'
allow_dns allow_infra20_dns 'infra20'
allow_dns allow_iot30_dns   'iot30'
allow_dns allow_family40_dns 'family40'
allow_dns allow_guest50_dns  'guest50'
allow_dns allow_admin60_dns  'admin60'

# Hijack peticiones DNS de cualquier zona al pihole. Evita DNS propios de algunos dispostivos
# Exluimos la zona 20, para evitar loop infinito
echo "[12/..] FIREWALL: HIJACK DNS..."
for red in dns_hj_lan10 dns_hj_iot30 dns_hj_fam40 dns_hj_guest50 ; do safe_del firewall.$red; done
mkhijack() {
  local name=$1 zone=$2
  uci set firewall.$name='redirect'
  uci set firewall.$name.name="DNS-Hijack-$zone → Pi-hole"
  uci set firewall.$name.src="$zone"
  uci set firewall.$name.proto='tcp udp'
  uci set firewall.$name.src_dport='53'
  uci set firewall.$name.dest='infra20'
  uci set firewall.$name.dest_ip='192.168.20.2'
  uci set firewall.$name.dest_port='53'
  uci set firewall.$name.target='DNAT'
  uci set firewall.$name.reflection='0'          # sin hairpin
}
mkhijack dns_hj_lan10 lan10
mkhijack dns_hj_iot30 iot30
mkhijack dns_hj_fam40 family40
mkhijack dns_hj_guest50 guest50

############################################################################
# PERMITIR DNS SALIENTE PARA PI-HOLE (INFRA20)
############################################################################
echo "[13/..] FIREWALL: PERMITIR DNS SALIENTE para Pi-hole..."
safe_del firewall.allow_infra20_dns_wan
uci set firewall.allow_infra20_dns_wan='rule'
uci set firewall.allow_infra20_dns_wan.name='a_Infra20-to-WAN-DNS'
uci set firewall.allow_infra20_dns_wan.src='infra20'
uci set firewall.allow_infra20_dns_wan.dest='wan'
uci set firewall.allow_infra20_dns_wan.proto='tcp udp'
uci set firewall.allow_infra20_dns_wan.dest_port='53'
uci set firewall.allow_infra20_dns_wan.target='ACCEPT'


############################################################################
# SSH
############################################################################

echo "[14/..] FIREWALL: SSH..."

for red in a_ssh_lan10_to_infra20 a_ssh_admin60_to_infra20 a_ssh_admin60_to_iot30; do safe_del firewall.$red; done

allow_ssh_to_() {
  local name=$1 src=$2 dest=$3 dest_ip=$4   # dest_ip opcional: limita a host concreto
  uci set firewall.$name='rule'
  uci set firewall.$name.name="Allow-SSH-$src-to-$dest"
  uci set firewall.$name.src="$src"
  uci set firewall.$name.dest="$dest"
  uci set firewall.$name.proto='tcp'
  uci set firewall.$name.dest_port='22'
  [ -n "$dest_ip" ] && uci set firewall.$name.dest_ip="$dest_ip"
  uci set firewall.$name.target='ACCEPT'
}

allow_ssh_to_ a_ssh_lan10_to_infra20 'lan10' 'infra20'
#allow_ssh_to_ a_ssh_lan10_to_iot30 'lan10' 'iot30' -> Limitamos SSH a iot desde admin60
allow_ssh_to_ a_ssh_admin60_to_infra20 'admin60' 'infra20'
allow_ssh_to_ a_ssh_admin60_to_iot30 'admin60' 'iot30'


echo "[15/..] FIREWALL: BLOQUEAR SSH DENTRO DE IOT30..."
safe_del firewall.no_intra_iot30_ssh
uci set firewall.no_intra_iot30_ssh='rule'
uci set firewall.no_intra_iot30_ssh.name='Block-Intra-IoT30-SSH'
uci set firewall.no_intra_iot30_ssh.src='iot30'
uci set firewall.no_intra_iot30_ssh.dest='iot30'
uci set firewall.no_intra_iot30_ssh.proto='tcp'
uci set firewall.no_intra_iot30_ssh.dest_port='22'
uci set firewall.no_intra_iot30_ssh.target='DROP'


############################################################################
# CLOUDFLARE
############################################################################
echo "[16/..] FIREWALL: PUERTOS CLOUDFLARE INFRA20 - TCP/UDP..."

# 1. Regla TCP: Permite 443 y 7844 (para control, fallbacks y http/https general)
safe_del firewall.allow_infra20_cf_tunnel_tcp
uci set firewall.allow_infra20_cf_tunnel_tcp='rule'
uci set firewall.allow_infra20_cf_tunnel_tcp.name='a_Infra20-CF-Tunnel-TCP'
uci set firewall.allow_infra20_cf_tunnel_tcp.src='infra20'
uci set firewall.allow_infra20_cf_tunnel_tcp.dest='wan'
uci set firewall.allow_infra20_cf_tunnel_tcp.proto='tcp'
uci set firewall.allow_infra20_cf_tunnel_tcp.dest_port='443 7844'
uci set firewall.allow_infra20_cf_tunnel_tcp.target='ACCEPT'

# 2. Regla UDP: Permite 7844 (para el protocolo QUIC, recomendado por Cloudflare)
safe_del firewall.allow_infra20_cf_tunnel_udp
uci set firewall.allow_infra20_cf_tunnel_udp='rule'
uci set firewall.allow_infra20_cf_tunnel_udp.name='a_Infra20-CF-Tunnel-UDP'
uci set firewall.allow_infra20_cf_tunnel_udp.src='infra20'
uci set firewall.allow_infra20_cf_tunnel_udp.dest='wan'
uci set firewall.allow_infra20_cf_tunnel_udp.proto='udp'
uci set firewall.allow_infra20_cf_tunnel_udp.dest_port='7844'
uci set firewall.allow_infra20_cf_tunnel_udp.target='ACCEPT'



############################################################################
# BORRAR LAN
############################################################################
# 1. Elimina la sección de la zona de firewall en el índice [0]
uci delete firewall.@zone[0]
# 2. Guarda los cambios
#uci commit firewall
# 3. Reinicia el firewall para aplicar la limpieza
#/etc/init.d/firewall restart

uci commit network
uci commit dhcp
uci commit firewall

echo "[17/..] Programando reinicios en 10 segundos..."
sleep 3
(
  sleep 10
  /etc/init.d/network restart
  sleep 5
  /etc/init.d/dnsmasq restart
  /etc/init.d/firewall restart
) &