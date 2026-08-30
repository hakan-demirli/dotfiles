# shellcheck shell=sh
# shellcheck disable=SC3043

R01_PWM_DIR=/sys/class/hwmon/hwmon2

router_fan_apply_mode() {
  local mode="$1" manual_pwm="$2" n

  [ -d "$R01_PWM_DIR" ] || return 0

  case "$mode" in
    auto)
      echo 2 > "$R01_PWM_DIR/pwm1_enable" 2> /dev/null
      ;;
    quiet)
      echo 1 > "$R01_PWM_DIR/pwm1_enable" 2> /dev/null
      echo 0 > "$R01_PWM_DIR/pwm1" 2> /dev/null
      ;;
    aggressive)
      echo 1 > "$R01_PWM_DIR/pwm1_enable" 2> /dev/null
      echo 255 > "$R01_PWM_DIR/pwm1" 2> /dev/null
      ;;
    manual)
      n="${manual_pwm:-128}"
      [ "$n" -lt 0 ] 2> /dev/null && n=0
      [ "$n" -gt 255 ] 2> /dev/null && n=255
      echo 1 > "$R01_PWM_DIR/pwm1_enable" 2> /dev/null
      echo "$n" > "$R01_PWM_DIR/pwm1" 2> /dev/null
      ;;
    *)
      echo 2 > "$R01_PWM_DIR/pwm1_enable" 2> /dev/null
      ;;
  esac
}
