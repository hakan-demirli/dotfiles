{
  pkgs,
  r01-ui,
  hostname,
  wifiToml ? null,
  eapPassword ? null,
  lanWifiPassword ? null,
  authorizedKeys ? null,
  tailscaleAuthKey ? null,
  tailscaleLoginServer ? null,
  bootstrap ? false,
}:
let
  inherit (pkgs) lib;

  filesRoot = ../files;
  systemConfig = pkgs.writeText "system" (
    lib.replaceStrings [ "__HOSTNAME__" ] [ hostname ] (builtins.readFile ../files/etc/config/system)
  );

  wifiTomlFile = if wifiToml == null then null else pkgs.writeText "wifi.toml" wifiToml;

  productionMode = lanWifiPassword != null;
  bootstrapMode = !productionMode && bootstrap;
  shipsWireless = productionMode || bootstrapMode;

  effectiveEapPassword = if eapPassword == null then "UNCONFIGURED-DO-NOT-DEPLOY" else eapPassword;

  wirelessProduction = pkgs.runCommand "wireless-production" { } ''
    substitute ${../files/etc/config/wireless} $out \
      --replace-quiet '__LAN_WIFI_PASSWORD__' ${
        lib.escapeShellArg (if lanWifiPassword == null then "" else lanWifiPassword)
      } \
      --replace-quiet '__EAP_PASSWORD__'      ${lib.escapeShellArg effectiveEapPassword}
  '';

  travelmateBaseline = pkgs.writeText "travelmate-baseline" ''
    config travelmate 'global'
    	option trm_enabled '0'
    	option trm_iface 'wwan'
    	option trm_captive '1'
    	option trm_proactive '0'
    	option trm_autoadd '0'
    	option trm_maxretry '5'
    	option trm_maxwait '30'
    	option trm_minquality '35'
    	option trm_listexpiry '0'
    	option trm_radio '''
    	option trm_debug '0'
  '';

  wirelessAndTravelmate =
    if productionMode && wifiTomlFile != null then
      pkgs.runCommand "wireless-and-travelmate" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        mkdir -p $out
        cp ${wirelessProduction} $out/wireless
        chmod u+w $out/wireless
        python3 ${./wifi-to-uci.py} \
          ${wifiTomlFile} \
          --wireless-out $out/wireless.sta \
          --travelmate-out $out/travelmate
        cat $out/wireless.sta >> $out/wireless
        rm $out/wireless.sta
      ''
    else if productionMode then
      pkgs.runCommand "wireless-and-travelmate" { } ''
        mkdir -p $out
        install -Dm0644 ${wirelessProduction}   $out/wireless
        install -Dm0644 ${travelmateBaseline}   $out/travelmate
      ''
    else if bootstrapMode then
      pkgs.runCommand "wireless-and-travelmate" { } ''
        mkdir -p $out
        install -Dm0644 ${../files/etc/config/wireless.bootstrap} $out/wireless
        install -Dm0644 ${travelmateBaseline}                     $out/travelmate
      ''
    else
      null;

  r01TailscaleUci =
    if tailscaleLoginServer == null then
      null
    else
      pkgs.writeText "r01-tailscale" ''
        config bootstrap 'main'
        	option login_server '${tailscaleLoginServer}'
      '';
in
pkgs.runCommand "router-0-config-overlay"
  {
    passthru = {
      inherit
        productionMode
        bootstrapMode
        shipsWireless
        tailscaleAuthKey
        tailscaleLoginServer
        hostname
        ;
      hasWifiToml = wifiTomlFile != null;
      isDeployable =
        productionMode || bootstrapMode || tailscaleAuthKey != null || authorizedKeys != null;
    };
  }
  ''
    mkdir -p $out/root

    install -Dm0755 -d $out/root/etc/config
    install -Dm0755 -d $out/root/etc/dropbear
    chmod 700 $out/root/etc/dropbear
    install -Dm0755 -d $out/root/etc/init.d
    install -Dm0755 -d $out/root/etc/uci-defaults
    install -Dm0755 -d $out/root/etc/tailscale
    chmod 700 $out/root/etc/tailscale
    install -Dm0755 -d $out/root/usr/bin
    install -Dm0755 -d $out/root/usr/libexec
    install -Dm0755 -d $out/root/lib
    install -Dm0755 -d $out/root/usr/share/luci/menu.d
    install -Dm0755 -d $out/root/usr/share/rpcd/acl.d
    install -Dm0755 -d $out/root/www/luci-static/resources/view/r01

    ${lib.optionalString shipsWireless ''
      install -Dm0644 ${wirelessAndTravelmate}/wireless   $out/root/etc/config/wireless
      install -Dm0644 ${wirelessAndTravelmate}/travelmate $out/root/etc/config/travelmate
    ''}

    install -Dm0644 ${filesRoot}/etc/config/network    $out/root/etc/config/network
    install -Dm0644 ${filesRoot}/etc/config/firewall   $out/root/etc/config/firewall
    install -Dm0644 ${filesRoot}/etc/config/dhcp       $out/root/etc/config/dhcp
    install -Dm0644 ${systemConfig}                    $out/root/etc/config/system
    install -Dm0644 ${filesRoot}/etc/config/r01        $out/root/etc/config/r01
    install -Dm0644 ${filesRoot}/etc/config/r01-ui     $out/root/etc/config/r01-ui

    install -Dm0644 ${filesRoot}/etc/config/prometheus-node-exporter-lua \
      $out/root/etc/config/prometheus-node-exporter-lua

    install -Dm0755 ${filesRoot}/etc/rc.local          $out/root/etc/rc.local

    install -Dm0755 -d $out/root/etc/rc.d
    for f in ${filesRoot}/etc/init.d/r01-*; do
      name="$(basename "$f")"
      install -Dm0755 "$f" "$out/root/etc/init.d/$name"

      start_line="$(grep -E '^START=[0-9]+' "$f" | head -n1 | cut -d= -f2 | tr -dc '0-9')"
      if [ -n "$start_line" ]; then
        padded="$(printf '%02d' "$start_line")"
        ln -sf "../init.d/$name" "$out/root/etc/rc.d/S$padded$name"
      fi
    done

    for f in ${filesRoot}/etc/uci-defaults/*; do
      install -Dm0755 "$f" "$out/root/etc/uci-defaults/$(basename "$f")"
    done

    install -Dm0644 ${filesRoot}/lib/r01-fan-modes.sh    $out/root/lib/r01-fan-modes.sh

    install -Dm0755 ${r01-ui}/bin/r01-ui                 $out/root/usr/bin/r01-ui
    install -Dm0755 ${filesRoot}/usr/bin/r01-ui-set-pin  $out/root/usr/bin/r01-ui-set-pin

    for f in ${filesRoot}/usr/libexec/r01-*; do
      install -Dm0755 "$f" "$out/root/usr/libexec/$(basename "$f")"
    done

    for f in ${filesRoot}/usr/share/luci/menu.d/*; do
      install -Dm0644 "$f" "$out/root/usr/share/luci/menu.d/$(basename "$f")"
    done

    for f in ${filesRoot}/usr/share/rpcd/acl.d/*; do
      install -Dm0644 "$f" "$out/root/usr/share/rpcd/acl.d/$(basename "$f")"
    done

    for f in ${filesRoot}/www/luci-static/resources/view/r01/*; do
      install -Dm0644 "$f" "$out/root/www/luci-static/resources/view/r01/$(basename "$f")"
    done

    ${lib.optionalString (authorizedKeys != null) ''
      install -Dm0600 ${pkgs.writeText "authorized_keys" authorizedKeys} \
        $out/root/etc/dropbear/authorized_keys
    ''}

    ${lib.optionalString (tailscaleAuthKey != null) ''
      install -Dm0600 ${pkgs.writeText "tailscale-authkey" tailscaleAuthKey} \
        $out/root/etc/tailscale/authkey
    ''}

    ${lib.optionalString (r01TailscaleUci != null) ''
      install -Dm0644 ${r01TailscaleUci} $out/root/etc/config/r01-tailscale
    ''}

    tar -C $out/root -czf $out/config-overlay.tar.gz .
    (cd $out && sha256sum config-overlay.tar.gz > config-overlay.tar.gz.sha256)
  ''
