set -euo pipefail

usage() {
  cat << 'EOF'
Usage: router-0-firmware-flash [options]

Streams a sysupgrade image to router-0 and flashes it. The image is verified
on the device before anything is written, and the running revision is checked
after the reboot.

Options:
  --router-ip IP     Router address (default: the lan_ip inventory fact)
  --firmware PATH    Image to flash (default: ./result-router-0/firmware.bin)
  --wipe             Pass -n to sysupgrade, discarding all on-device state
  --check            Run every preflight check, then stop without flashing
  -h, --help         Show this help

Transfer uses an ssh pipe rather than scp: dropbear ships no SFTP server and
busybox provides no scp, so neither protocol has a peer on the device.
EOF
}

log() { printf '[router-0-firmware-flash] %s\n' "$*" >&2; }
die() {
  log "ERROR: $*"
  exit 1
}

router_ip=${R0_DEFAULT_IP:?internal error: R0_DEFAULT_IP unset}
expected_revision=${R0_EXPECTED_REVISION:?internal error: R0_EXPECTED_REVISION unset}
firmware="./result-router-0/firmware.bin"
wipe=0
check_only=0

while (($# > 0)); do
  case $1 in
    --router-ip)
      router_ip=$2
      shift 2
      ;;
    --firmware)
      firmware=$2
      shift 2
      ;;
    --wipe)
      wipe=1
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

ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
# shellcheck disable=SC2029
on_router() { ssh "${ssh_opts[@]}" "root@$router_ip" "$@"; }

[[ -f $firmware ]] || die "firmware image not found: $firmware (run: nix run .#router-0-firmware)"

image_size=$(stat -c %s "$firmware")
((image_size > 0)) || die "firmware image is empty: $firmware"
local_sum=$(sha256sum "$firmware" | cut -d' ' -f1)
log "image $firmware ($image_size bytes, sha256 ${local_sum:0:16}...)"

on_router true 2> /dev/null || die "cannot reach root@$router_ip over ssh"

board=$(on_router 'cat /tmp/sysinfo/board_name' 2> /dev/null || true)
[[ $board == "glinet,gl-be10000" ]] \
  || die "refusing to flash: device reports board '$board', expected 'glinet,gl-be10000'"

tmp_free=$(on_router "df -k /tmp | awk 'NR==2 {print \$4}'")
tmp_free_bytes=$((tmp_free * 1024))
((tmp_free_bytes > image_size)) \
  || die "device /tmp has $tmp_free_bytes bytes free, image needs $image_size"

running=$(on_router 'sed -n "s/^DISTRIB_REVISION=.//p" /etc/openwrt_release | tr -d "\047"' || true)
log "device is running $running, image expects $expected_revision"

if ((check_only)); then
  log "preflight passed for root@$router_ip"
  exit 0
fi

log "streaming image to device /tmp"
on_router 'cat > /tmp/firmware.bin' < "$firmware"

log "verifying image checksum on the device"
on_router "echo '$local_sum  /tmp/firmware.bin' | sha256sum -c -" > /dev/null \
  || die "checksum mismatch on the device; refusing to flash"

flags=(-v)
if ((wipe)); then
  flags+=(-n)
fi
log "flashing with sysupgrade ${flags[*]} (the ssh session will drop; this is expected)"
on_router "sysupgrade ${flags[*]} /tmp/firmware.bin" || true

log "waiting for the device to come back"
deadline=$((SECONDS + 300))
until on_router true 2> /dev/null; do
  ((SECONDS < deadline)) || die "device did not return within 300s"
  sleep 5
done

booted=$(on_router 'sed -n "s/^DISTRIB_REVISION=.//p" /etc/openwrt_release | tr -d "\047"')
[[ $booted == "$expected_revision" ]] \
  || die "device booted revision $booted, expected $expected_revision"

log "flash complete, device is running $booted"
if ((wipe)); then
  log "state was wiped: the device is on its default address until you push config"
fi
log "run 'nix run .#router-0-config' to restore configuration and secrets"
