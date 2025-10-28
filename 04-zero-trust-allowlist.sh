#!/bin/sh
# 04-zero-trust-allowlist.sh
# Ejecutar DESPUÉS de 03-setup-zero-trust.sh
set -e

echo "[4/10] Zero-trust allowlist (idempotente) …"

# ---------- Helpers ----------
safe_del() { uci -q delete "$1" || true; }

# Borra reglas por .name exacto (idempotente)
_del_rules_by_name() {
  local n="$1" idx path
  for idx in $(uci show firewall | sed -n 's/^firewall\.@rule\[\([0-9]\+\)\]=.*/\1/p'); do
    path="firewall.@rule[$idx]"
    [ "$(uci -q get $path.name 2>/dev/null)" = "$n" ] && uci -q delete "$path"
  done
}

mk_forward() {
  # mk_forward SECTION_NAME SRC_ZONE DEST_ZONE
  local name="$1" src="$2" dst="$3"
  safe_del "firewall.$name"
  uci set "firewall.$name=forwarding"
  uci set "firewall.$name.src=$src"
  uci set "firewall.$name.dest=$dst"
}

norm_name() {
  # minúsculas y solo [a-z0-9_]
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g'
}


allow_service() {
  # allow_service "NAME" SRC_ZONE DEST_ZONE "tcp udp|tcp|udp|icmp" "PUERTOS" [DEST_IP] [COMMENT]
  local name="$1" src="$2" dst="$3" proto="$4" dports="$5" dip="${6:-}" comment="${7:-}"
  local key="r_$(norm_name "$name")"

  safe_del "firewall.$key"        # idempotente
  uci set "firewall.$key=rule" || return 1
  uci set "firewall.$key.name=$name"
  uci set "firewall.$key.src=$src"
  uci set "firewall.$key.dest=$dst"
  uci set "firewall.$key.target=ACCEPT"
  uci set "firewall.$key.family=ipv4"

  # En modo compat: usa 'set' (string). fw3/fw4 aceptan "tcp udp" y "80 443".
  [ -n "$proto"  ] && uci set "firewall.$key.proto=$proto"
  [ -n "$dports" ] && uci set "firewall.$key.dest_port=$dports"
  [ -n "$dip"    ] && uci set "firewall.$key.dest_ip=$dip"
  [ -n "$comment" ] && uci set "firewall.$key.comment=$comment"
}


# ---------- Parámetros de tu red ----------
PIHOLE_IP="192.168.20.2"
NAS_IP="192.168.20.3"
ALL_ZONES="lan10 infra20 iot30 family40 guest50 admin60"

# ---------- 1) Eliminar TODOS los forwardings existentes ----------
echo "[1/10] Limpieza de forwardings previos…"
while uci -q delete firewall.@forwarding[0]; do :; done

# ---------- 2) Forwardings mínimos a WAN (con safe_del por sección) ----------
echo "[2/10] Forwardings a WAN…"
for Z in $ALL_ZONES; do
  mk_forward "f_${Z}_wan" "$Z" "wan"
done

# ---------- 3) Forwarding explícito LAN10 → INFRA20 (gestión total) ----------
echo "[3/10] Forwarding LAN10 → INFRA20 (gestión)…"
mk_forward "f_lan10_infra20" "lan10" "infra20"
mk_forward "f_lan60_infra20" "lan60" "infra20"

# ---------- 4) Reglas explícitas de servicio ----------
echo "[4/10] DNS: todas las VLAN → Pi-hole ($PIHOLE_IP:53)…"
for SRC in $ALL_ZONES; do
  allow_service "Allow-DNS-${SRC}-to-PiHole" "$SRC" "infra20" "tcp udp" "53" "$PIHOLE_IP" "DNS $SRC -> $PIHOLE_IP"
done

echo "[5/10] FAMILY40 → Jellyfin en NAS ($NAS_IP:8096/8920)…"
allow_service "Allow-Web-FAM40-to-Jellyfin" "family40" "infra20" "tcp" "8096 8920" "$NAS_IP" "Jellyfin en NAS"

echo "[6/10] LAN10/FAMILY40 → Samba en NAS ($NAS_IP)…"
# TCP 445/139
allow_service "Allow-SMB-TCP-LAN10-to-NAS"   "lan10"    "infra20" "tcp" "445 139" "$NAS_IP" "SMB TCP LAN10 -> NAS"
allow_service "Allow-SMB-TCP-FAM40-to-NAS"   "family40" "infra20" "tcp" "445 139" "$NAS_IP" "SMB TCP FAM40 -> NAS"
# UDP 137/138 (opcional; desactiva si no necesitas NetBIOS discovery)
allow_service "Allow-SMB-UDP-LAN10-to-NAS"   "lan10"    "infra20" "udp" "137 138" "$NAS_IP" "SMB UDP LAN10 -> NAS"
allow_service "Allow-SMB-UDP-FAM40-to-NAS"   "family40" "infra20" "udp" "137 138" "$NAS_IP" "SMB UDP FAM40 -> NAS"


# NTP a NAS (si el NAS actúa como servidor NTP)
#allow_service "Allow-NTP-All-to-NAS" "lan10"    "infra20" "udp" "123" "$NAS_IP" "NTP LAN10 -> NAS"
#allow_service "Allow-NTP-All-to-NAS2" "family40" "infra20" "udp" "123" "$NAS_IP" "NTP FAM40 -> NAS"
#allow_service "Allow-NTP-All-to-NAS3" "iot30"    "infra20" "udp" "123" "$NAS_IP" "NTP IoT -> NAS"
#allow_service "Allow-NTP-All-to-NAS4" "guest50"  "infra20" "udp" "123" "$NAS_IP" "NTP Guest -> NAS"

# Home Assitant si IoT necesesitara hablar con NS
#allow_service "Allow-IoT-to-HA" "iot30" "infra20" "tcp" "8123" "192.168.20.X" "IoT -> Home Assistant"


# ---------- 6) Aplicar ----------
echo "[8/10] Commit & restart…"
uci commit firewall
echo "Commit done"
/etc/init.d/firewall restart

echo "[9/10] Listo. Allowlist aplicada con safe_del en todo."
