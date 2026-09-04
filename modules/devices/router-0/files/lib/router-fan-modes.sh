#!/bin/sh

router_fan_find_pwm_dir() {
  for _rf_dir in /sys/class/hwmon/hwmon*; do
    [ -r "$_rf_dir/name" ] || continue
    IFS= read -r _rf_name < "$_rf_dir/name" || continue
    if [ "$_rf_name" = "pwmfan" ]; then
      ROUTER_PWM_DIR="$_rf_dir"
      return 0
    fi
  done
  return 1
}

router_fan_apply_mode() {
  router_fan_find_pwm_dir || return 0

  case "$1" in
    auto)
      echo 2 > "$ROUTER_PWM_DIR/pwm1_enable" 2> /dev/null
      ;;
    quiet)
      echo 1 > "$ROUTER_PWM_DIR/pwm1_enable" 2> /dev/null
      echo 0 > "$ROUTER_PWM_DIR/pwm1" 2> /dev/null
      ;;
    aggressive)
      echo 1 > "$ROUTER_PWM_DIR/pwm1_enable" 2> /dev/null
      echo 255 > "$ROUTER_PWM_DIR/pwm1" 2> /dev/null
      ;;
    manual)
      _rf_pwm="${2:-128}"
      [ "$_rf_pwm" -lt 0 ] 2> /dev/null && _rf_pwm=0
      [ "$_rf_pwm" -gt 255 ] 2> /dev/null && _rf_pwm=255
      echo 1 > "$ROUTER_PWM_DIR/pwm1_enable" 2> /dev/null
      echo "$_rf_pwm" > "$ROUTER_PWM_DIR/pwm1" 2> /dev/null
      ;;
    *)
      echo 2 > "$ROUTER_PWM_DIR/pwm1_enable" 2> /dev/null
      ;;
  esac
}
