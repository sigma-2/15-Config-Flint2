#!/bin/ash
# 03-setup-zero-trust.sh
set -e

################################################################################
# anunciar Pi-hole como DNS y (opcional) bloquear IPv6 autoconfig
################################################################################

# ---------- Verificación de prerequisitos ----------
echo "[0/10] Verificando zonas del firewall..."
for z in lan10 infra20 iot30 family40 guest50 admin60; do
  if ! uci -q get firewall.$z.name >/dev/null; then
    echo "ERROR: Zona '$z' no encontrada. Debes ejecutar antes 01-config-inicial-luci.sh (y 02 si aplica)."
    exit 1
  fi
done
echo "Zonas OK."


echo "[1/10] Anunciando pi-hole..."
# Anunciar Pi-hole (192.168.20.2) como DNS en todas las VLAN
for IF in lan10 infra20 iot30 family40 guest50 admin60; do
  uci -q delete dhcp.$IF.dhcp_option || true
  # DHCP option 6 = DNS servidores (separados por coma)
  uci add_list dhcp.$IF.dhcp_option='6,192.168.20.2'
done

# (Opcional “anti-leaks”) Desactivar RA/DHCPv6 si no usas IPv6 interno
for IF in lan10 infra20 iot30 family40 guest50 admin60; do
  uci set dhcp.$IF.dhcpv6='disabled'
  uci set dhcp.$IF.ra='disabled'
  uci add_list dhcp.$IF.dhcp_option='6,192.168.20.2,192.168.20.3'
done

uci commit dhcp
/etc/init.d/dnsmasq restart
echo "DHCP listo (Pi-hole distribuido como DNS)."

################################################################################
# Zona zero-trust + reglas explícitas
################################################################################
echo "[2/10] Limpieza de zonas antiguas..."
safe_del() { uci -q delete "$1" >/dev/null 2>&1 || true; }

# Limpieza de restos/zonas antiguas potencialmente conflictivas
for pat in 'wan6' 'wwan' 'secondwan' 'wgserver' 'ovpnserver' 'guest$' 'guest[^0-9]'; do
  for sec in $(uci show firewall 2>/dev/null | grep -E "$pat" | cut -d. -f3 | cut -d= -f1 | sort -u); do
    safe_del firewall.$sec
  done
done
# Borra zonas "lan" y "guest" legacy si quedaran
for idx in $(uci show firewall 2>/dev/null | grep "=zone" | cut -d. -f3 | cut -d= -f1); do
  name=$(uci -q get firewall.$idx.name)
  [ "$name" = "lan" ] && safe_del firewall.$idx
  [ "$name" = "guest" ] && safe_del firewall.$idx
done

# === ZONAS ZERO-TRUST =====================================================
# INPUT = REJECT en todas excepto admin60 (gestión)
# FORWARD = REJECT en todas. Abriremos lo necesario con reglas específicas.
echo "[3/10] Zonas zero-trust..."
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
uci set firewall.iot30.input='REJECT'
uci set firewall.iot30.output='ACCEPT'
uci set firewall.iot30.forward='REJECT'
uci add_list firewall.iot30.network='iot30'

uci set firewall.family40='zone'
uci set firewall.family40.name='family40'
uci set firewall.family40.input='REJECT'
uci set firewall.family40.output='ACCEPT'
uci set firewall.family40.forward='REJECT'
uci add_list firewall.family40.network='family40'

uci set firewall.guest50='zone'
uci set firewall.guest50.name='guest50'
uci set firewall.guest50.input='REJECT'
uci set firewall.guest50.output='ACCEPT'
uci set firewall.guest50.forward='REJECT'
uci add_list firewall.guest50.network='guest50'

uci set firewall.admin60='zone'
uci set firewall.admin60.name='admin60'
uci set firewall.admin60.input='ACCEPT'
uci set firewall.admin60.output='ACCEPT'
uci set firewall.admin60.forward='REJECT'
uci add_list firewall.admin60.network='admin60'

# === BÁSICAS: DHCP para todas las VLAN (el router da DHCP) ================
echo "[4/10] DHCP para todas las vlan..."
for r in r_all_dhcp_l10 r_all_dhcp_s20 r_all_dhcp_i30 r_all_dhcp_f40 r_all_dhcp_g50 r_all_dhcp_a60; do safe_del firewall.$r; done
mkdhcp() {
  local name=$1 zone=$2
  uci set firewall.$name='rule'
  uci set firewall.$name.name="Allow-DHCP-$zone"
  uci set firewall.$name.src="$zone"
  uci set firewall.$name.proto='udp'
  uci set firewall.$name.dest_port='67-68'
  uci set firewall.$name.target='ACCEPT'
}
mkdhcp r_all_dhcp_l10 lan10
mkdhcp r_all_dhcp_s20 infra20
mkdhcp r_all_dhcp_i30 iot30
mkdhcp r_all_dhcp_f40 family40
mkdhcp r_all_dhcp_g50 guest50
mkdhcp r_all_dhcp_a60 admin60

echo "[5/10] DHCP para todas las vlan..."
# (Opcional) Permitir ping al router desde LAN10 y ADMIN60 (útil para diagnóstico)
for r in r_ping_l10 r_ping_a60; do safe_del firewall.$r; done
uci set firewall.r_ping_l10='rule'
uci set firewall.r_ping_l10.name='Allow-Ping-lan10'
uci set firewall.r_ping_l10.src='lan10'
uci set firewall.r_ping_l10.proto='icmp'
uci set firewall.r_ping_l10.icmp_type='echo-request'
uci set firewall.r_ping_l10.target='ACCEPT'

uci set firewall.r_ping_a60='rule'
uci set firewall.r_ping_a60.name='Allow-Ping-admin60'
uci set firewall.r_ping_a60.src='admin60'
uci set firewall.r_ping_a60.proto='icmp'
uci set firewall.r_ping_a60.icmp_type='echo-request'
uci set firewall.r_ping_a60.target='ACCEPT'

# === DNS HIJACK: forzar todo 53 -> 192.168.20.2 (Pi-hole) =================
# Esto aplica a lan10, family40, guest50, iot30, admin60, infra20
echo "[6/10] DNS Hijack..."
for red in dns_hj_l10 dns_hj_f40 dns_hj_g50 dns_hj_i30 dns_hj_a60 dns_hj_s20; do safe_del firewall.$red; done
mkhijack() {
  local name=$1 zone=$2
  uci set firewall.$name='redirect'
  uci set firewall.$name.name="DNS-Hijack-$zone"
  uci set firewall.$name.src="$zone"
  uci set firewall.$name.proto='tcp udp'
  uci set firewall.$name.src_dport='53'
  uci set firewall.$name.dest='infra20'
  uci set firewall.$name.dest_ip='192.168.20.2'
  uci set firewall.$name.dest_port='53'
  uci set firewall.$name.target='DNAT'
}
mkhijack dns_hj_l10 lan10
mkhijack dns_hj_f40 family40
mkhijack dns_hj_g50 guest50
mkhijack dns_hj_i30 iot30
mkhijack dns_hj_a60 admin60
mkhijack dns_hj_s20 infra20

# === WAN: salida a Internet para zonas de usuario ==========================
# ---------- Utilidades ----------
safe_del() { uci -q delete "$1" >/dev/null 2>&1 || true; }

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

# ---------- (Opcional) asegurar forwardings a WAN sin duplicar ----------
# Si en este script añades forwardings a WAN, usa 'ensure_forwarding' para no duplicar.
# Si NO gestionas WAN aquí, puedes borrar todo este bloque.
echo "[7/10] Asegurando forwardings a WAN (sin duplicar)..."
# Descomenta según tu política (estos coinciden con el 01):
ensure_forwarding f_lan10_wan   'lan10'   'wan'
ensure_forwarding f_infra20_wan 'infra20' 'wan'
ensure_forwarding f_family40_wan 'family40' 'wan'
ensure_forwarding f_guest50_wan  'guest50' 'wan'
ensure_forwarding f_iot30_wan    'iot30'   'wan'
ensure_forwarding f_admin60_wan  'admin60' 'wan'



# === ACCESOS ESPECÍFICOS ENTRE VLANs ======================================
echo "[8/10] Accesos específicos..."
# 2.1 LAN10 -> NAS (192.168.20.3) en SERVICIOS concretos
# - 443/80: vía Nginx/Cloudflare (Nextcloud/Paperless/Immich reverse proxy)
# - 8000 (Paperless-ngx directo), 2283 (Immich directo)
# - SMB/NFS: 445, 139, 137-138 (udp), 2049 (NFS), 111 (portmap), 20048 (mountd)
safe_del firewall.r_l10_nas_web
uci set firewall.r_l10_nas_web='rule'
uci set firewall.r_l10_nas_web.name='L10->NAS web/revproxy'
uci set firewall.r_l10_nas_web.src='lan10'
uci set firewall.r_l10_nas_web.dest='infra20'
uci set firewall.r_l10_nas_web.dest_ip='192.168.20.3'
uci set firewall.r_l10_nas_web.proto='tcp'
uci set firewall.r_l10_nas_web.dest_port='80 443 8000 2283'
uci set firewall.r_l10_nas_web.target='ACCEPT'

safe_del firewall.r_l10_nas_smbnfs
uci set firewall.r_l10_nas_smbnfs='rule'
uci set firewall.r_l10_nas_smbnfs.name='L10->NAS SMB/NFS'
uci set firewall.r_l10_nas_smbnfs.src='lan10'
uci set firewall.r_l10_nas_smbnfs.dest='infra20'
uci set firewall.r_l10_nas_smbnfs.dest_ip='192.168.20.3'
uci set firewall.r_l10_nas_smbnfs.proto='tcp udp'
uci set firewall.r_l10_nas_smbnfs.dest_port='445 139 137 138 2049 111 20048'
uci set firewall.r_l10_nas_smbnfs.target='ACCEPT'

# (Opcional) Jellyfin directo si no vas por proxy: 8096 (http) / 8920 (https)
# uci set firewall.r_l10_nas_jelly='rule'; uci set firewall.r_l10_nas_jelly.name='L10->NAS Jellyfin'
# uci set firewall.r_l10_nas_jelly.src='lan10'; uci set firewall.r_l10_nas_jelly.dest='infra20'
# uci set firewall.r_l10_nas_jelly.dest_ip='192.168.20.3'; uci set firewall.r_l10_nas_jelly.proto='tcp'
# uci set firewall.r_l10_nas_jelly.dest_port='8096 8920'; uci set firewall.r_l10_nas_jelly.target='ACCEPT'

# 2.2 LAN10 -> CUPS (impresión en NAS) puerto 631
safe_del firewall.r_l10_nas_cups
uci set firewall.r_l10_nas_cups='rule'
uci set firewall.r_l10_nas_cups.name='L10->NAS CUPS'
uci set firewall.r_l10_nas_cups.src='lan10'
uci set firewall.r_l10_nas_cups.dest='infra20'
uci set firewall.r_l10_nas_cups.dest_ip='192.168.20.3'
uci set firewall.r_l10_nas_cups.proto='tcp udp'
uci set firewall.r_l10_nas_cups.dest_port='631'
uci set firewall.r_l10_nas_cups.target='ACCEPT'

# 2.3 LAN10 -> Home Assistant (192.168.30.2) puerto 8123
safe_del firewall.r_l10_ha
uci set firewall.r_l10_ha='rule'
uci set firewall.r_l10_ha.name='L10->HA 8123'
uci set firewall.r_l10_ha.src='lan10'
uci set firewall.r_l10_ha.dest='iot30'
uci set firewall.r_l10_ha.dest_ip='192.168.30.2'
uci set firewall.r_l10_ha.proto='tcp'
uci set firewall.r_l10_ha.dest_port='8123'
uci set firewall.r_l10_ha.target='ACCEPT'

# 2.4 (Opcional) ADMIN60 -> NAS/HA SSH (gestión) puerto 22
#   Más seguro que abrir SSH desde LAN10
safe_del firewall.r_a60_ssh_nas
uci set firewall.r_a60_ssh_nas='rule'
uci set firewall.r_a60_ssh_nas.name='A60->NAS SSH'
uci set firewall.r_a60_ssh_nas.src='admin60'
uci set firewall.r_a60_ssh_nas.dest='infra20'
uci set firewall.r_a60_ssh_nas.dest_ip='192.168.20.3'
uci set firewall.r_a60_ssh_nas.proto='tcp'
uci set firewall.r_a60_ssh_nas.dest_port='22'
uci set firewall.r_a60_ssh_nas.target='ACCEPT'

safe_del firewall.r_a60_ssh_ha
uci set firewall.r_a60_ssh_ha='rule'
uci set firewall.r_a60_ssh_ha.name='A60->HA SSH'
uci set firewall.r_a60_ssh_ha.src='admin60'
uci set firewall.r_a60_ssh_ha.dest='iot30'
uci set firewall.r_a60_ssh_ha.dest_ip='192.168.30.2'
uci set firewall.r_a60_ssh_ha.proto='tcp'
uci set firewall.r_a60_ssh_ha.dest_port='22'
uci set firewall.r_a60_ssh_ha.target='ACCEPT'

echo "[9/10] Guardando cambios..."
uci commit firewall

# Reinicios
echo "[10/10] Reinicando firewall..."
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart

echo "Zero-trust aplicado. Verifica conectividad."


## Comprobaciones rápidas
# Zonas y políticas
uci show firewall | grep "=zone" -n
uci show firewall | grep "name='\(lan10\|infra20\|iot30\|family40\|guest50\|admin60\)'" -n

# DNS hijack activo (deberían verse 6 redirects)
uci show firewall | grep 'DNS-Hijack' -n

# Conectividad desde un host de LAN10:
# - Navega a https://nextcloud.tu-dominio (si proxy) o https://192.168.20.3
# - Acceso a HA: http(s)://192.168.30.2:8123
# - SMB: \\192.168.20.3
# - NFS: showmount -e 192.168.20.3