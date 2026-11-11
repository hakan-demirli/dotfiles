#!/usr/bin/env bash
set -u
set -o pipefail

PORT=/dev/port
DMI=/sys/class/dmi/id
EC_DATA=0x62
EC_CMD=0x66
EC_OBF=0x01
EC_IBF=0x02
EC_RD=0x80
EC_WR=0x81
EC_WAIT_TRIES=500
EC_TEMP_SYS=0x05
EC_TEMP_CPU=0x09
EC_PROFILE=0x2f
EC_PROFILE_VALID="177 178"
SIO_INDEX=0x2e
SIO_DATA=0x2f
LEVEL_MAX=60
SYS_ADDRS=(0x30 0x33 0x36)
SYS_DEFAULTS=(26 36 36)
CPU_ADDRS=(0x13 0x16 0x19 0x1c 0x1f 0x22 0x25)
CPU_DEFAULTS=(16 16 22 26 30 33 35)

inb() {
  dd if="$PORT" bs=1 count=1 skip=$(($1)) 2> /dev/null | od -An -tu1 | tr -d ' \n'
}

outb() {
  printf '%b' "\\x$(printf '%02x' "$(($2))")" \
    | dd of="$PORT" bs=1 count=1 seek=$(($1)) conv=notrunc status=none 2> /dev/null
}

ec_status() {
  local s
  s=$(inb $EC_CMD)
  [[ $s =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$s"
}

ec_wait() {
  local want=$1 i s
  for ((i = 0; i < EC_WAIT_TRIES; i++)); do
    s=$(ec_status) || return 1
    case $want in
      ibf) ((s & EC_IBF)) || return 0 ;;
      obf) ((s & EC_OBF)) && return 0 ;;
    esac
  done
  echo "  FAIL EC timeout waiting for $want" >&2
  return 1
}

ec_flush() {
  local s
  s=$(ec_status) || return 1
  if ((s & EC_OBF)); then
    inb $EC_DATA > /dev/null
  fi
}

ec_read() {
  local v
  ec_flush || return 1
  ec_wait ibf || return 1
  outb $EC_CMD $EC_RD || return 1
  ec_wait ibf || return 1
  outb $EC_DATA "$1" || return 1
  ec_wait obf || return 1
  v=$(inb $EC_DATA)
  [[ $v =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$v"
}

ec_write() {
  ec_flush || return 1
  ec_wait ibf || return 1
  outb $EC_CMD $EC_WR || return 1
  ec_wait ibf || return 1
  outb $EC_DATA "$1" || return 1
  ec_wait ibf || return 1
  outb $EC_DATA "$2" || return 1
  ec_wait ibf
}

sio_write() {
  outb $SIO_INDEX "$1" && outb $SIO_DATA "$2"
}

sio_read() {
  outb $SIO_INDEX "$1" || return 1
  inb $SIO_DATA
}

i2ec_read() {
  sio_write 0x2e 0x11 && sio_write 0x2f $(($1 >> 8)) \
    && sio_write 0x2e 0x10 && sio_write 0x2f $(($1 & 0xff)) \
    && sio_write 0x2e 0x12 && sio_read 0x2f
}

fan_rpm() {
  local lo hi count
  lo=$(i2ec_read "$1") || return 1
  hi=$(i2ec_read "$2") || return 1
  count=$((hi << 8 | lo))
  if ((count == 0)); then
    echo 0
  else
    echo $(((2156220 + count / 2) / count))
  fi
}

check_system() {
  local product bios
  product=$(cat "$DMI/product_name" 2> /dev/null)
  bios=$(cat "$DMI/bios_version" 2> /dev/null)
  if [ "$product" != "MS-A2" ] || [ "$bios" != "1.02" ]; then
    echo "  ABORT unsupported system '$product' BIOS '$bios' (need MS-A2 BIOS 1.02)" >&2
    return 99
  fi
  [ -w "$PORT" ] || {
    echo "  ABORT $PORT not writable (kernel lockdown?)" >&2
    return 99
  }
}

check_level() {
  local v
  v=$(ec_read "$1") || return 1
  if ((v < $2 || v > LEVEL_MAX)); then
    printf '  ABORT EC 0x%02x = %d, expected %d..%d\n' "$(($1))" "$v" "$2" "$LEVEL_MAX" >&2
    return 99
  fi
}

check_ec() {
  local profile i
  profile=$(ec_read $EC_PROFILE) || return 1
  case " $EC_PROFILE_VALID " in
    *" $profile "*) ;;
    *)
      printf '  ABORT EC profile 0x%02x is not 0xb1/0xb2 (BIOS fan mode must be Auto)\n' "$profile" >&2
      return 99
      ;;
  esac
  for i in "${!SYS_ADDRS[@]}"; do
    check_level "${SYS_ADDRS[$i]}" "${SYS_DEFAULTS[$i]}" || return $?
  done
  for i in "${!CPU_ADDRS[@]}"; do
    check_level "${CPU_ADDRS[$i]}" "${CPU_DEFAULTS[$i]}" || return $?
  done
}

read_levels() {
  local -n _addrs=$1
  local a v out=()
  for a in "${_addrs[@]}"; do
    v=$(ec_read "$a") || v="?"
    out+=("$v")
  done
  echo "${out[*]}"
}

write_checked() {
  local addr=$1 val=$2 cur
  cur=$(ec_read "$addr") || return 1
  [ "$cur" -eq "$val" ] && return 0
  ec_write "$addr" "$val" || return 1
  cur=$(ec_read "$addr") || return 1
  if [ "$cur" -ne "$val" ]; then
    printf '  FAIL EC 0x%02x: wrote %d reads %d\n' "$((addr))" "$val" "$cur" >&2
    return 1
  fi
}

set_curve() {
  local name=$1 level=$2 i v
  local -n _set_addrs=$3 _set_defaults=$4
  for i in "${!_set_addrs[@]}"; do
    v=${_set_defaults[$i]}
    ((level > v)) && v=$level
    write_checked "${_set_addrs[$i]}" "$v" || return 1
  done
  echo "  ok   $name fan levels = $(read_levels "$3")"
}

parse_level() {
  if [[ ${1:-} =~ ^[0-9]{1,2}$ ]] && ((10#$1 <= LEVEL_MAX)); then
    echo $((10#$1))
    return 0
  fi
  echo "bad level '${1:-}' (need 0..$LEVEL_MAX, units of 100 rpm)" >&2
  return 2
}

print_status() {
  local cpu_temp sys_temp profile id_hi id_lo
  cpu_temp=$(ec_read $EC_TEMP_CPU)
  sys_temp=$(ec_read $EC_TEMP_SYS)
  profile=$(ec_read $EC_PROFILE)
  echo "EC temp cpu / system : ${cpu_temp:-?} / ${sys_temp:-?} C"
  printf 'EC profile (0x2F)    : 0x%02x\n' "${profile:-0}"
  echo "System fan levels    : $(read_levels SYS_ADDRS) (firmware ${SYS_DEFAULTS[*]})"
  echo "CPU fan levels       : $(read_levels CPU_ADDRS) (firmware ${CPU_DEFAULTS[*]})"
  id_hi=$(i2ec_read 0x2000)
  id_lo=$(i2ec_read 0x2001)
  if [ "${id_hi:-}" = 85 ] && [ "${id_lo:-}" = 113 ]; then
    echo "Fan rpm cpu / system : $(fan_rpm 0x181e 0x181f) / $(fan_rpm 0x1820 0x1821)"
  else
    echo "Fan rpm cpu / system : (IT5571 not found over I2EC)"
  fi
}

cmd_status() {
  check_system || return $?
  check_ec || return $?
  print_status
}

apply() {
  local mode=$1 sys=$2 cpu=$3 fail=0
  check_system || return $?
  check_ec || return $?
  echo "==> $mode: system fan floor=$sys cpu fan floor=$cpu"
  set_curve system "$sys" SYS_ADDRS SYS_DEFAULTS || fail=1
  set_curve cpu "$cpu" CPU_ADDRS CPU_DEFAULTS || fail=1
  return "$fail"
}

cmd_apply() {
  case "${1:-}" in
    turbo) apply turbo 60 60 ;;
    balanced) apply balanced 50 0 ;;
    silent) apply silent 0 0 ;;
    *)
      echo "unknown mode: ${1:-}" >&2
      return 2
      ;;
  esac
}

cmd_curve() {
  local name=$1 addrs=$2 defaults=$3 level
  shift 3
  local -n _cmd_defaults=$defaults
  check_system || return $?
  check_ec || return $?
  if [ -z "${1:-}" ]; then
    echo "$name fan levels = $(read_levels "$addrs") (firmware ${_cmd_defaults[*]})"
    return 0
  fi
  level=$(parse_level "$1") || return $?
  echo "$name fan floor <- $level:"
  set_curve "$name" "$level" "$addrs" "$defaults"
}

cmd_read() {
  local addr v
  [[ ${1:-} =~ ^(0x)?[0-9a-fA-F]{1,2}$ ]] || {
    echo "bad address '${1:-}' (need 0x00..0xff)" >&2
    return 2
  }
  addr=$((16#${1#0x}))
  check_system || return $?
  v=$(ec_read "$addr") || return 1
  printf 'EC 0x%02x = 0x%02x (%d)\n' "$addr" "$v" "$v"
}

cmd_help() {
  cat << 'EOF'
Board: Minisforum MS-A2
Needs BIOS 1.02 and BIOS fan mode "Auto". Fan levels are units of 100 rpm.
Fan rpm needs root, so json reports it as unknown.

  turbo                 system fan floor 60, cpu fan floor 60 (both full speed)
  balanced              system fan floor 50, cpu fan firmware
  silent                both fans firmware
  sys [level]  [sudo]   read or write system (SSD) fan floor 0..60
  cpu [level]  [sudo]   read or write cpu fan floor 0..60
  read ADDR    [sudo]   read one EC RAM byte 0x00..0xff

A floor never lowers a curve point below its firmware value.

EC RAM (ports 0x62/0x66, RD 0x80, WR 0x81):
  0x05 system temp  0x09 cpu temp  0x2F profile (0xb1/0xb2 in Auto)
  0x30 0x33 0x36                     system fan levels (firmware 26 36 36)
  0x13 0x16 0x19 0x1C 0x1F 0x22 0x25 cpu fan levels (firmware 16 16 22 26 30 33 35)
I2EC (Super I/O 0x2E/0x2F):
  0x2000/0x2001 chip id 55 71
  0x181E/0x181F cpu tach, 0x1820/0x1821 system tach, rpm = 2156220 / count

Persistence:
  EC levels reset on EC reset (power loss), possibly on reboot. Just re-run.
EOF
}

cmd_run() {
  local cmd=${1:-}
  shift
  case "$cmd" in
    sys) cmd_curve system SYS_ADDRS SYS_DEFAULTS "$@" ;;
    cpu) cmd_curve cpu CPU_ADDRS CPU_DEFAULTS "$@" ;;
    read) cmd_read "$@" ;;
    *)
      echo "unknown command: $cmd" >&2
      return 2
      ;;
  esac
}

case "${1:-}" in
  apply) cmd_apply "${2:-}" ;;
  status) cmd_status ;;
  rpm) exit 1 ;;
  commands) printf '%s\n' sys cpu read ;;
  run)
    shift
    cmd_run "$@"
    ;;
  help) cmd_help ;;
  *)
    echo "usage: ${0##*/} {apply MODE|status|rpm|commands|run COMMAND...|help}" >&2
    exit 2
    ;;
esac
