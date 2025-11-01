#/bin/ash
# ---------- Parámetros de tu red ----------
PIHOLE_IP="192.168.20.2"
NAS_IP="192.168.20.3"
ALL_ZONES="lan10 infra20 iot30 family40 guest50 admin60"

##########################################
# ------------ Helpers -------------------
##########################################

##########################################
# ------------ FUNCIÓN PRINCIPAL -----------------
##########################################

# Funcion para crear una regla de firewall (tipo 'rule')
# Parametros:
# $1: nombre_regla (Ej: "Allow-Jellyfin-FAM40")
# $2: src_zone (Ej: "family40")
# $3: dest_zone (Ej: "infra20")
# $4: dest_ip (Ej: "192.168.20.3")
# $5: proto (Ej: "tcp", "udp", "tcp udp")
# $6: dports (Ej: "8096 8920") - ¡Los puertos van separados por ESPACIOS!
# $7: comment (Opcional, Ej: "Acceso al servidor multimedia")
allow_simple_service() {
  local name="$1"
  local src="$2"
  local dst="$3"
  local dest_ip="$4"
  local proto="$5"
  local dports="$6"
  local comment="$7"
  
  # Usamos el nombre de la regla para el identificador UCI, eliminando espacios
  local key=$(echo "$name" | tr -d '[:space:]')

  # Validaciones mínimas
  [ -z "$name" ] || [ -z "$src" ] || [ -z "$dst" ] || [ -z "$proto" ] && {
    echo "ERROR: Campos nombre, origen, destino o protocolo están vacíos." >&2
    return 1
  }
  
  safe_del "firewall.$key"

  uci set "firewall.$key=rule"
  uci set "firewall.$key.name=$name"
  uci set "firewall.$key.src=$src"
  uci set "firewall.$key.dest=$dst"
  uci set "firewall.$key.target=ACCEPT"
  uci set "firewall.$key.family=ipv4"

  [ -n "$dest_ip" ] && uci set "firewall.$key.dest_ip=$dest_ip"
  [ -n "$proto"   ] && uci set "firewall.$key.proto=$proto"

  # Los puertos se manejan como una lista separada por espacios en UCI
  if [ -n "$dports" ]; then
    # Limpiamos y añadimos los puertos como un único string (UCI lo interpreta como lista)
    uci set "firewall.$key.dest_port=$dports"
  fi

  [ -n "$comment" ] && uci set "firewall.$key.comment=$comment"
  
  echo "Regla '$name' creada."
}

##########################################
# ------------ EJEMPLO DE USO -------------------
##########################################

#echo "Aplicando reglas de firewall simplificadas..."

# [1] Jellyfin (FAMILY40 -> INFRA20:NAS)
#allow_simple_service \
#  "Jellyfin-FAM40-to-NAS" \
#  "family40" \
#  "infra20" \
#  "$NAS_IP" \
#  "tcp" \
#  "8096 8920" \
#  "Acceso web y remoto a Jellyfin"

# [2] DNS (LAN10 -> INFRA20:PiHole)
#allow_simple_service \
#  "DNS-LAN10-to-PiHole" \
#  "lan10" \
#  "infra20" \
#  "$PIHOLE_IP" \
#  "tcp udp" \
#  "53" \
#  "Permitir peticiones DNS al Pi-hole central"

# [3] PING (ADMIN60 -> INFRA20) - Sin especificar puertos, ICMP es el protocolo
#allow_simple_service \
#  "Ping-Admin60-to-Infra20" \
#  "admin60" \
#  "infra20" \
#  "" \
#  "icmp" \
#  "" \
#  "Permitir ping desde Admin a Infraestructura"

# Guardar y aplicar
#uci commit firewall
#/etc/init.d/firewall restart
#echo "Reglas de firewall commiteadas."


###################################################################
#
###################################################################

# [1] Jellyfin (FAMILY40 -> INFRA20:NAS)
allow_simple_service \
  "Jellyfin-FAM40-to-NAS" \
  "family40" \
  "infra20" \
  "$NAS_IP" \
  "tcp" \
  "8096 8920" \
  "Acceso web y remoto a Jellyfin"

# [2] Jellyfin (LAN10 -> INFRA20:NAS)
allow_simple_service \
  "Jellyfin-LAN10-to-NAS" \
  "lan10" \
  "infra20" \
  "$NAS_IP" \
  "tcp" \
  "8096 8920" \
  "Acceso web y remoto a Jellyfin"

# Syncthing (lan10 -> NAS)
allow_service \
  "Syncthing-Sync-LAN10-to-NAS" \
  "lan10" \
  "infra20" \
  "tcp" \
  "22000" \
  "$NAS_IP" \
  "comment:Permitir sync desde lan10 al NAS"

# Syncthing Web GUI (lan10 -> NAS)
allow_service \
  "Syncthing-GUI-LAN10-to-NAS" \
  "lan10" \
  "infra20" \
  "tcp" \
  "8384" \
  "$NAS_IP" \
  "comment:Acceso a la interfaz web de Syncthing desde lan10"

# DE AQUI EN ADELANTE FALLA

echo "[1/..] FAMILY40 → Jellyfin en NAS ($NAS_IP:8096/8920)…"
allow_service "Allow-Web-FAM40-to-Jellyfin" "family40" "infra20" "tcp" "8096 8920" "$NAS_IP" "Jellyfin en NAS"

echo "[2/..] LAN10/FAMILY40 → Samba en NAS ($NAS_IP)…"
# TCP 445/139
allow_service "Allow-SMB-TCP-LAN10-to-NAS"   "lan10"    "infra20" "tcp" "445 139" "$NAS_IP" "SMB TCP LAN10 -> NAS"
allow_service "Allow-SMB-TCP-FAM40-to-NAS"   "family40" "infra20" "tcp" "445 139" "$NAS_IP" "SMB TCP FAM40 -> NAS"
# UDP 137/138 (opcional; desactiva si no necesitas NetBIOS discovery)
allow_service "Allow-SMB-UDP-LAN10-to-NAS"   "lan10"    "infra20" "udp" "137 138" "$NAS_IP" "SMB UDP LAN10 -> NAS"
allow_service "Allow-SMB-UDP-FAM40-to-NAS"   "family40" "infra20" "udp" "137 138" "$NAS_IP" "SMB UDP FAM40 -> NAS"

echo "[16/..] LAN10 NFS NAS ($NAS_IP)…"
# Sustituye 192.168.20.3 por la IP de tu NAS en infra20
allow_service "NFSv4 lan10→NAS" lan10 infra20 tcp 2049 192.168.20.3 comment:"NFSv4 only"

# Si NFSv3
#allow_service "nfsd 2049 lan10→NAS"   lan10 infra20 "tcp udp" 2049 192.168.20.3
#allow_service "rpcbind 111 lan10→NAS" lan10 infra20 "tcp udp" 111  192.168.20.3
#allow_service "mountd 20048 lan10→NAS" lan10 infra20 "tcp udp" 20048 192.168.20.3
# Nota: en NFSv3 mountd/lockd/statd pueden ir en puertos variables.
# Fíjalos en el NAS para que no bailen (p.ej., mountd=20048, lockd=4045, statd=32765-32766, rquotad=875)
# y añade reglas si los usas:
#allow_service "lockd 4045 lan10→NAS"   lan10 infra20 "tcp udp" 4045 192.168.20.3
#allow_service "statd 32765-32766 lan10→NAS" lan10 infra20 "tcp udp" "32765 32766" 192.168.20.3
#allow_service "rquotad 875 lan10→NAS"  lan10 infra20 "tcp udp" 875  192.168.20.3


# Comprueba si existe un forwarding src->dest (para evitar duplicados)
# NOTA: Esta función DEBE existir en una sección previa del script
# has_forwarding() { ... }

# Crea un forwarding sólo si no existe ya el par src->dest
# NOTA: Esta función DEBE existir en una sección previa del script
# ensure_forwarding() { ... }

echo "[3/..] FIREWALL: Configurando acceso completo de admin60 a todas las zonas..."

# Solo si quieres admin60 con vía libre a todas las zonas
for z in lan10 infra20 iot30 family40 guest50 wan; do
  # El nombre de la sección UCI se genera de forma descriptiva
  NAME="f_admin60_to_$z" 
  SRC='admin60'
  DEST="$z"
  
  # Usamos la función ensure_forwarding para evitar duplicados
  ensure_forwarding "$NAME" "$SRC" "$DEST"
done




###################################################################
#
###################################################################
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