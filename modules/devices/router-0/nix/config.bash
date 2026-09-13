set -euo pipefail

umask 077

usage() {
  cat << 'EOF'
Usage: router-0-config [options]

Options:
  --repo PATH        Dotfiles repository (default: current directory)
  --router-ip IP     Router address (default: the lan_ip inventory fact)
  --bootstrap        Push the cold-start overlay (public AP, no secrets)
  --with-tailscale   Also install the headscale pre-auth key
  --force            Push even when the device already matches
  --check            Resolve and render everything, then stop without pushing
  -h, --help         Show this help
EOF
}

log() { printf '[router-0-config] %s\n' "$*" >&2; }
die() {
  log "ERROR: $*"
  exit 1
}

repo="$(pwd -P)"
router_ip=${R0_DEFAULT_IP:?internal error: R0_DEFAULT_IP unset}
bootstrap=0
with_tailscale=0
force=0
check_only=0

while (($# > 0)); do
  case $1 in
    --repo)
      repo=$2
      shift 2
      ;;
    --router-ip)
      router_ip=$2
      shift 2
      ;;
    --bootstrap)
      bootstrap=1
      shift
      ;;
    --with-tailscale)
      with_tailscale=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
    --check)
      check_only=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

repo="$(realpath -m "$repo")"
[[ -f $repo/flake.nix ]] || die "repository is not a flake: $repo"

overlay=$R0_OVERLAY
if ((bootstrap)); then
  overlay=$R0_OVERLAY_BOOTSTRAP
fi

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
# shellcheck disable=SC2029
on_router() { ssh "${ssh_opts[@]}" "root@$router_ip" "$@"; }

stage="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/router-0-config.XXXXXX")"
chmod 0700 "$stage"
trap 'rm -rf "$stage"' EXIT

log "staging overlay from $overlay"
mkdir -p "$stage/root"
cp -a "$overlay/root/." "$stage/root/"
chmod -R u+w "$stage/root"

secret_material="$stage/secret-material"
: > "$secret_material"

if ((bootstrap)); then
  log "cold-start overlay: no secrets are resolved"
else
  wifi_key="$HOME/.config/sops/age/wifi.key"
  [[ -s $wifi_key ]] || die "wifi identity is missing: $wifi_key"

  log "decrypting wifi credentials"
  SOPS_AGE_KEY_FILE="$wifi_key" sops --decrypt "$repo/secrets/wifi/networks.yaml" \
    | remarshal -if yaml -of json > "$stage/networks.json" \
    || die "could not decrypt secrets/wifi/networks.yaml"

  lan_psk="$(
    python3 -c '
import json,sys
nets = json.load(open(sys.argv[1]))["networks"]
marked = [v for v in nets.values() if v.get("lan_ap")]
if len(marked) != 1:
    raise SystemExit(f"expected exactly one network with lan_ap, found {len(marked)}")
sys.stdout.write(marked[0]["psk"])
' "$stage/networks.json"
  )" || die "could not resolve the LAN AP password"

  log "rendering wireless uplinks"
  python3 "$R0_WIFI_TO_UCI" \
    --networks "$stage/networks.json" \
    --wireless-out "$stage/wireless.sta" \
    --travelmate-out "$stage/root/etc/config/travelmate"

  python3 -c '
import pathlib, sys
target = pathlib.Path(sys.argv[1])
target.write_text(target.read_text().replace("__LAN_WIFI_PASSWORD__", sys.argv[2]))
' "$stage/root/etc/config/wireless" "$lan_psk"

  cat "$stage/wireless.sta" >> "$stage/root/etc/config/wireless"
  rm -f "$stage/wireless.sta"
  chmod 0644 "$stage/root/etc/config/wireless" "$stage/root/etc/config/travelmate"

  log "decrypting router deploy secrets"
  operator_key="$HOME/.config/sops/age/keys.txt"
  [[ -s $operator_key ]] || die "operator identity is missing: $operator_key"
  SOPS_AGE_KEY_FILE="$operator_key" sops --decrypt "$repo/secrets/router-0/deploy.yaml" \
    | remarshal -if yaml -of json > "$stage/deploy.json" \
    || die "could not decrypt secrets/router-0/deploy.yaml"

  root_password="$(
    python3 -c '
import json, sys
value = json.load(open(sys.argv[1]))["authentication"]["root_password"]
if not isinstance(value, str) or len(value) < 32 or "\n" in value:
    raise SystemExit("root password must be a single line with at least 32 characters")
sys.stdout.write(value)
' "$stage/deploy.json"
  )" || die "could not resolve the router root password"
  printf '%s' "$root_password" | openssl passwd -6 -stdin > "$stage/root-password-hash"
  unset root_password
  root_password_hash="$(cat "$stage/root-password-hash")"
  [[ $root_password_hash == \$6\$* ]] || die "could not hash the router root password"
  unset root_password_hash
  chmod 0600 "$stage/root-password-hash"

  log "resolving the switch-0 quarantine rule"
  switch_mac="$(
    SOPS_AGE_KEY_FILE="$operator_key" sops \
      --config "$repo/secrets/switch-0/.sops.yaml" \
      --decrypt --extract '["switchMac"]' \
      "$repo/secrets/switch-0/deploy.yaml"
  )" || die "could not read switchMac from secrets/switch-0/deploy.yaml"
  [[ $switch_mac =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] \
    || die "switchMac is not a MAC address: $switch_mac"

  python3 -c '
import pathlib, sys
target = pathlib.Path(sys.argv[1])
target.write_text(target.read_text().replace("__SWITCH_0_MAC__", sys.argv[2]))
' "$stage/root/etc/config/firewall" "$switch_mac"

  python3 -c '
import json
import pathlib
import re
import sys

deploy = json.load(open(sys.argv[1]))["iot"]
password = deploy["wifi_password"]
mac = deploy["devices"]["plug_0_mac"]
if not isinstance(password, str) or len(password) < 32 or "\n" in password:
    raise SystemExit("IoT Wi-Fi password must be a single line with at least 32 characters")
if not isinstance(mac, str) or not re.fullmatch(r"(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}", mac):
    raise SystemExit("plug_0_mac must be a MAC address")
for filename, token, value in (
    (sys.argv[2], "__IOT_WIFI_PASSWORD__", password),
    (sys.argv[3], "__SHELLY_PLUG_0_MAC__", mac),
):
    target = pathlib.Path(filename)
    text = target.read_text()
    if text.count(token) != 1:
        raise SystemExit(f"expected one {token} in {filename}")
    target.write_text(text.replace(token, value))
' "$stage/deploy.json" "$stage/root/etc/config/wireless" "$stage/root/etc/config/dhcp"

  install -m0600 "$R0_AUTHORIZED_KEYS" "$stage/root/etc/dropbear/authorized_keys"

  if ((with_tailscale)); then
    envelope="$repo/secrets/bootstrap/tailscale.age.key.enc"
    expected="$(tr -d '\n' < "$repo/secrets/bootstrap/tailscale.age.pub")"
    ts_key="$HOME/.config/sops/age/bootstrap-tailscale.key"

    if [[ ! -s $ts_key ]] || [[ $(age-keygen -y "$ts_key" 2> /dev/null) != "$expected" ]]; then
      [[ -s $envelope ]] || die "tailscale identity envelope is missing: $envelope"
      log "PASSPHRASE FOR: bootstrap-tailscale (headscale pre-auth key)"
      ts_key="$stage/tailscale.key"
      age --decrypt --output "$ts_key" "$envelope" || die "could not decrypt the tailscale identity"
      chmod 0600 "$ts_key"
      [[ $(age-keygen -y "$ts_key") == "$expected" ]] \
        || die "tailscale identity has the wrong recipient"
    fi

    SOPS_AGE_KEY_FILE="$ts_key" sops --decrypt \
      --extract '["headscale"]["bootstrap-preauth-key"]' \
      "$repo/secrets/bootstrap/tailscale.yaml" > "$stage/root/etc/tailscale/authkey" \
      || die "could not decrypt the headscale pre-auth key"
    chmod 0600 "$stage/root/etc/tailscale/authkey"
  fi

  {
    printf '%s' "$lan_psk"
    cat "$stage/deploy.json"
    if ((with_tailscale)); then
      cat "$stage/root/etc/tailscale/authkey"
    fi
  } >> "$secret_material"
fi

for token in __IOT_WIFI_PASSWORD__ __LAN_WIFI_PASSWORD__ __SHELLY_PLUG_0_MAC__ __SWITCH_0_MAC__; do
  if grep -rlF "$token" "$stage/root" > /dev/null 2>&1; then
    die "unresolved $token token remains in the staged tree"
  fi
done

(cd "$stage/root" && find . -type f -o -type l | LC_ALL=C sort | sed 's|^\./||') > "$stage/manifest"

tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -C "$stage/root" -czf "$stage/overlay.tar.gz" .

tree_digest=$(sha256sum "$stage/overlay.tar.gz" | cut -d' ' -f1)
secret_digest=$(sha256sum "$secret_material" | cut -d' ' -f1)
stamp="${tree_digest:0:32}${secret_digest:0:32}"
log "overlay digest ${tree_digest:0:16}... ($(wc -l < "$stage/manifest") files)"

if ((check_only)); then
  log "check passed; nothing was pushed"
  exit 0
fi

on_router true 2> /dev/null || die "cannot reach root@$router_ip over ssh"

current=$(on_router 'cat /etc/router-deploy/stamp 2>/dev/null' || true)
if [[ $current == "$stamp" ]] && ((! force)); then
  log "device already matches this configuration; nothing to do"
  exit 0
fi

log "pushing overlay to root@$router_ip"
on_router 'cat > /tmp/router-overlay.tar.gz' < "$stage/overlay.tar.gz"
on_router 'cat > /tmp/router-manifest' < "$stage/manifest"

if ((bootstrap == 0)); then
  on_router 'umask 077; cat > /tmp/router-root-password-hash' < "$stage/root-password-hash"
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))["router_ui"]
sys.stdout.write(d["admin_pin"] + "\n" + d["guest_pin"] + "\n")
' "$stage/deploy.json" | on_router 'umask 077; cat > /tmp/router-pins'
fi

log "applying on the device"
on_router "STAMP='$stamp' sh -s" << 'REMOTE'
set -e
mkdir -p /etc/router-deploy
chmod 0700 /etc/router-deploy

active_sta=$(uci show wireless 2>/dev/null \
  | sed -n "s/^wireless\.\(sta_[a-z0-9_]*\)\.disabled='0'$/\1/p" | head -1)

tar -xzf /tmp/router-overlay.tar.gz -C /

if [ -s /tmp/router-root-password-hash ]; then
  root_password_hash=$(cat /tmp/router-root-password-hash)
  awk -F: -v OFS=: -v hash="$root_password_hash" '
    $1 == "root" { $2 = hash; found = 1 }
    { print }
    END { if (!found) exit 1 }
  ' /etc/shadow > /tmp/router-shadow
  chmod 0600 /tmp/router-shadow
  chown root:root /tmp/router-shadow
  mv /tmp/router-shadow /etc/shadow
  unset root_password_hash
  rm -f /tmp/router-root-password-hash
fi

if [ -f /etc/router-deploy/manifest ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    grep -qxF "$path" /tmp/router-manifest || rm -f "/$path"
  done < /etc/router-deploy/manifest
fi
cp /tmp/router-manifest /etc/router-deploy/manifest

if [ -f /tmp/router-pins ]; then
  admin_pin=$(sed -n 1p /tmp/router-pins)
  guest_pin=$(sed -n 2p /tmp/router-pins)
  [ -n "$admin_pin" ] && /usr/bin/router-ui-set-pin admin "$admin_pin" >/dev/null 2>&1 || true
  [ -n "$guest_pin" ] && /usr/bin/router-ui-set-pin guest "$guest_pin" >/dev/null 2>&1 || true
  rm -f /tmp/router-pins
fi

printf '%s' "$STAMP" > /etc/router-deploy/stamp
chmod 0600 /etc/router-deploy/stamp

rm -f /tmp/router-overlay.tar.gz /tmp/router-manifest /tmp/router-root-password-hash

if [ -x /sbin/reload_config ]; then
  /sbin/reload_config
else
  /etc/init.d/network reload || true
  /etc/init.d/firewall reload || true
fi

for s in /etc/init.d/router-*; do
  [ -x "$s" ] || continue
  [ "$s" = /etc/init.d/router-dns-telemetry ] && continue
  "$s" enable 2>/dev/null || true
  "$s" restart 2>/dev/null || true
done

if [ -x /etc/init.d/router-dns-telemetry ]; then
  /etc/init.d/router-dns-telemetry enable
  /etc/init.d/router-dns-telemetry restart
  /etc/init.d/dnsmasq restart
fi

if [ -f /etc/config/travelmate ]; then
  if [ "$(uci -q get travelmate.global.trm_enabled)" = "1" ]; then
    /etc/init.d/travelmate enable 2>/dev/null || true
    /etc/init.d/travelmate restart 2>/dev/null || true
  else
    /etc/init.d/travelmate stop 2>/dev/null || true
    /etc/init.d/travelmate disable 2>/dev/null || true
  fi
fi

i=0
while [ "$i" -lt 45 ]; do
  ip route | grep -q '^default' && break
  i=$((i + 5))
  sleep 5
done
if ! ip route | grep -q '^default' && [ -n "$active_sta" ]; then
  logger -t router-0-config "no uplink after push, restoring $active_sta"
  uci set "wireless.$active_sta.disabled=0"
  uci commit wireless
  wifi reload
fi
REMOTE

log "configuration applied to root@$router_ip"
