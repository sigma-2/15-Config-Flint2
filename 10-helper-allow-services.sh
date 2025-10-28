# ============================================
# Helper: allow_service
# Crea una regla granular de firewall del tipo "ACCEPT"
# Uso:
#   allow_service NAME \
#     --src-zone lan10 [--src-ip "192.168.10.5,192.168.10.20/32"] \
#     --dest-zone infra20 [--dest-ip "192.168.20.2,192.168.20.3"] \
#     --proto "tcp udp" --dport "53" \
#     [--family ipv4|ipv6|any] \
#     [--comment "texto opcional"]
#
# Notas:
# - NAME debe ser único. Se borrará/rehacera si ya existe.
# - --dport acepta uno o varios puertos/rangos (ej: "53", "80 443", "8000-8100").
# - --proto acepta uno o varios protocolos (ej: "tcp", "udp", "tcp udp", "icmp").
# - Puedes usar solo zonas, o zonas + dest_ip/src_ip para granularidad.
# - Por defecto family=ipv4 (cámbialo a ipv6 o any si lo necesitas).
# - Requiere UCI (OpenWrt fw4). Funciona bien con tu política zero-trust.
# ============================================

allow_service() {
  local name=""
  local src_zone="" dest_zone=""
  local src_ip_list="" dest_ip_list=""
  local proto="" dport=""
  local family="ipv4"
  local comment=""

  # --- Parseo simple de flags ---
  name="$1"; shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --src-zone)   src_zone="$2"; shift 2 ;;
      --dest-zone)  dest_zone="$2"; shift 2 ;;
      --src-ip)     src_ip_list="$2"; shift 2 ;;
      --dest-ip)    dest_ip_list="$2"; shift 2 ;;
      --proto)      proto="$2"; shift 2 ;;
      --dport)      dport="$2"; shift 2 ;;
      --family)     family="$2"; shift 2 ;;
      --comment)    comment="$2"; shift 2 ;;
      *) echo "allow_service: argumento no reconocido: $1" >&2; return 2 ;;
    esac
  done

  # --- Validación mínima ---
  if [ -z "$name" ] || [ -z "$src_zone" ] || [ -z "$dest_zone" ] || [ -z "$proto" ] || [ -z "$dport" ]; then
    echo "allow_service: faltan argumentos obligatorios.
  Requeridos: NAME --src-zone Z --dest-zone Z --proto \"tcp|udp|...\" --dport \"PUERTO(S)\"" >&2
    return 2
  fi

  # Normaliza nombre (sin espacios)
  local uci_name
  uci_name="$(echo "$name" | tr ' ' '_' )"

  # Idempotencia por nombre: usa safe_del si existe; si no, borra por nombre
  if command -v safe_del >/dev/null 2>&1; then
    safe_del "firewall.$uci_name"
  else
    # Borrado por coincidencia exacta del campo .name
    # shellcheck disable=SC2046
    for idx in $(uci show firewall | awk -F':' '/=rule/{print $1}' | awk -F'@' '{print $2}' | sed 's/rule\[//;s/\]//'); do
      local path="firewall.@rule[$idx]"
      if [ "$(uci -q get $path.name 2>/dev/null)" = "$name" ]; then
        uci -q delete "$path"
      fi
    done
  fi

  # Crea la regla
  uci add firewall rule >/dev/null
  uci rename firewall.@rule[-1]="$uci_name"

  uci set firewall.$uci_name.name="$name"
  uci set firewall.$uci_name.src="$src_zone"
  uci set firewall.$uci_name.dest="$dest_zone"
  uci set firewall.$uci_name.proto="$proto"
  uci set firewall.$uci_name.dest_port="$dport"
  uci set firewall.$uci_name.target='ACCEPT'
  uci set firewall.$uci_name.family="${family}"

  # Listas de IPs (coma-separadas)
  IFS=',' read -r -a _SRC_ARR <<< "$src_ip_list"
  for ip in "${_SRC_ARR[@]}"; do
    [ -n "$ip" ] && uci add_list firewall.$uci_name.src_ip="$ip"
  done
  IFS=',' read -r -a _DST_ARR <<< "$dest_ip_list"
  for ip in "${_DST_ARR[@]}"; do
    [ -n "$ip" ] && uci add_list firewall.$uci_name.dest_ip="$ip"
  done
  unset _SRC_ARR _DST_ARR

  [ -n "$comment" ] && uci set firewall.$uci_name.comment="$comment"
}
