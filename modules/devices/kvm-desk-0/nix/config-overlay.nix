{
  pkgs,
  authorizedKeys ? null,
  tailscaleAuthKey ? null,
  tailscaleLoginServer ? null,
  staticIp ? null,
  hostname ? null,
  usbVid ? null,
  usbPid ? null,
  usbManufacturer ? null,
  usbProduct ? null,
  webAdminPasswordHash ? null,
  customEdid ? null,
  hdmiMode ? null,
  hdmiWidth ? null,
  hdmiHeight ? null,
}:
let
  inherit (pkgs) lib;

  filesRoot = ../files;

  shipsAuthorizedKeys = authorizedKeys != null;
  shipsTailscaleAuthKey = tailscaleAuthKey != null;
  shipsStaticIp = staticIp != null;
  shipsHostname = hostname != null;
  shipsUsbOverride =
    usbVid != null || usbPid != null || usbManufacturer != null || usbProduct != null;
  shipsWebAdmin = webAdminPasswordHash != null;
  shipsCustomEdid = customEdid != null;
  shipsHdmiMode = hdmiMode != null || hdmiWidth != null || hdmiHeight != null;

  isDeployable =
    shipsAuthorizedKeys
    || shipsTailscaleAuthKey
    || shipsStaticIp
    || shipsHostname
    || shipsUsbOverride
    || shipsWebAdmin
    || shipsCustomEdid
    || shipsHdmiMode;
in
pkgs.runCommand "kvm-desk-0-config-overlay"
  {
    passthru = {
      inherit
        shipsAuthorizedKeys
        shipsTailscaleAuthKey
        shipsStaticIp
        shipsHostname
        shipsUsbOverride
        shipsWebAdmin
        shipsCustomEdid
        shipsHdmiMode
        isDeployable
        ;
    };
  }
  ''
    mkdir -p $out/root

    install -Dm0755 -d $out/root/boot
    install -Dm0755 -d $out/root/root/.ssh
    chmod 700 $out/root/root/.ssh
    install -Dm0755 -d $out/root/etc/tailscale
    chmod 700 $out/root/etc/tailscale
    install -Dm0755 -d $out/root/etc/systemd/system
    install -Dm0755 -d $out/root/etc/systemd/system/multi-user.target.wants
    install -Dm0755 -d $out/root/usr/local/sbin
    install -Dm0755 -d $out/root/etc/kvm

    ${lib.optionalString shipsUsbOverride (
      lib.optionalString (usbVid != null) ''
        install -Dm0644 ${
          pkgs.writeText "usb.vid" (usbVid + "\n")
        }                     $out/root/boot/usb.vid
      ''
      + lib.optionalString (usbPid != null) ''
        install -Dm0644 ${
          pkgs.writeText "usb.pid" (usbPid + "\n")
        }                     $out/root/boot/usb.pid
      ''
      + lib.optionalString (usbManufacturer != null) ''
        install -Dm0644 ${
          pkgs.writeText "usb.manufacturer" (usbManufacturer + "\n")
        }   $out/root/boot/usb.manufacturer
      ''
      + lib.optionalString (usbProduct != null) ''
        install -Dm0644 ${
          pkgs.writeText "usb.product" (usbProduct + "\n")
        }             $out/root/boot/usb.product
      ''
    )}

    ${lib.optionalString (!shipsUsbOverride) ''
      install -Dm0644 ${filesRoot}/boot/usb.vid           $out/root/boot/usb.vid
      install -Dm0644 ${filesRoot}/boot/usb.pid           $out/root/boot/usb.pid
      install -Dm0644 ${filesRoot}/boot/usb.manufacturer  $out/root/boot/usb.manufacturer
      install -Dm0644 ${filesRoot}/boot/usb.product       $out/root/boot/usb.product
    ''}

    ${lib.optionalString shipsStaticIp ''
      install -Dm0644 ${pkgs.writeText "eth.nodhcp" (staticIp + "\n")} $out/root/boot/eth.nodhcp
    ''}

    ${lib.optionalString shipsHostname ''
      install -Dm0644 ${pkgs.writeText "hostname" (hostname + "\n")} $out/root/etc/hostname
    ''}

    install -Dm0755 ${filesRoot}/usr/local/sbin/kvm-tailscale-bootstrap \
      $out/root/usr/local/sbin/kvm-tailscale-bootstrap

    install -Dm0644 ${filesRoot}/etc/systemd/system/kvm-tailscale-bootstrap.service \
      $out/root/etc/systemd/system/kvm-tailscale-bootstrap.service

    ln -sf ../kvm-tailscale-bootstrap.service \
      $out/root/etc/systemd/system/multi-user.target.wants/kvm-tailscale-bootstrap.service

    ${lib.optionalString shipsTailscaleAuthKey ''
      install -Dm0600 ${pkgs.writeText "tailscale-authkey" tailscaleAuthKey} \
        $out/root/etc/tailscale/authkey
    ''}

    ${lib.optionalString (tailscaleLoginServer != null) ''
      install -Dm0644 ${pkgs.writeText "tailscale-login-server" (tailscaleLoginServer + "\n")} \
        $out/root/etc/tailscale/login-server
    ''}

    ${lib.optionalString shipsAuthorizedKeys ''
      install -Dm0600 ${pkgs.writeText "authorized_keys" authorizedKeys} \
        $out/root/root/.ssh/authorized_keys
    ''}

    ${lib.optionalString shipsWebAdmin ''
      install -Dm0600 ${pkgs.writeText "web-admin-hash" webAdminPasswordHash} \
        $out/root/etc/kvm/web-admin.hash
    ''}

    ${lib.optionalString shipsCustomEdid ''
      install -Dm0755 -d $out/root/kvmcomm/edid
      install -Dm0644 ${customEdid} $out/root/kvmcomm/edid/custom.bin
    ''}

    ${lib.optionalString (hdmiMode != null) ''
      install -Dm0644 ${pkgs.writeText "hdmi_mode" (toString hdmiMode + "\n")} \
        $out/root/etc/kvm/hdmi_mode
    ''}

    ${lib.optionalString (hdmiWidth != null) ''
      install -Dm0755 -d $out/root/kvmapp/kvm
      install -Dm0644 ${pkgs.writeText "hdmi-width" (toString hdmiWidth + "\n")} \
        $out/root/kvmapp/kvm/width
    ''}

    ${lib.optionalString (hdmiHeight != null) ''
      install -Dm0755 -d $out/root/kvmapp/kvm
      install -Dm0644 ${pkgs.writeText "hdmi-height" (toString hdmiHeight + "\n")} \
        $out/root/kvmapp/kvm/height
    ''}

    tar -C $out/root -czf $out/config-overlay.tar.gz .
    (cd $out && sha256sum config-overlay.tar.gz > config-overlay.tar.gz.sha256)
  ''
