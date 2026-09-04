{
  pkgs,
  router-ui,
  hostname,
  tailscaleLoginServer ? null,
  bootstrap ? false,
}:
let
  inherit (pkgs) lib;

  filesRoot = ../files;

  systemConfig = pkgs.writeText "system" (
    lib.replaceStrings [ "__HOSTNAME__" ] [ hostname ] (builtins.readFile ../files/etc/config/system)
  );

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

  wirelessSource =
    if bootstrap then ../files/etc/config/wireless.bootstrap else ../files/etc/config/wireless;

  routerTailscaleUci =
    if tailscaleLoginServer == null then
      null
    else
      pkgs.writeText "router-tailscale" ''
        config bootstrap 'main'
        	option login_server '${tailscaleLoginServer}'
      '';
in
pkgs.runCommand "router-0-config-overlay"
  {
    passthru = {
      inherit bootstrap hostname tailscaleLoginServer;
      requiredTokens = lib.optionals (!bootstrap) [ "__LAN_WIFI_PASSWORD__" ];
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
    install -Dm0755 -d $out/root/www/luci-static/resources/view/router

    install -Dm0644 ${wirelessSource}                  $out/root/etc/config/wireless
    ${lib.optionalString bootstrap ''
      install -Dm0644 ${travelmateBaseline}            $out/root/etc/config/travelmate
    ''}

    install -Dm0644 ${filesRoot}/etc/config/network    $out/root/etc/config/network
    install -Dm0644 ${filesRoot}/etc/config/firewall   $out/root/etc/config/firewall
    install -Dm0644 ${filesRoot}/etc/config/dhcp       $out/root/etc/config/dhcp
    install -Dm0644 ${systemConfig}                    $out/root/etc/config/system
    install -Dm0644 ${filesRoot}/etc/config/router        $out/root/etc/config/router
    install -Dm0644 ${filesRoot}/etc/config/router-ui     $out/root/etc/config/router-ui

    install -Dm0644 ${filesRoot}/etc/config/prometheus-node-exporter-lua \
      $out/root/etc/config/prometheus-node-exporter-lua

    install -Dm0755 ${filesRoot}/etc/rc.local          $out/root/etc/rc.local

    install -Dm0755 -d $out/root/etc/rc.d
    for f in ${filesRoot}/etc/init.d/router-*; do
      name="$(basename "$f")"
      install -Dm0755 "$f" "$out/root/etc/init.d/$name"

      start_line="$(grep -E '^START=[0-9]+' "$f" | head -n1 | cut -d= -f2 | tr -dc '0-9' || true)"
      if [ -n "$start_line" ]; then
        padded="$(printf '%02d' "$start_line")"
        ln -sf "../init.d/$name" "$out/root/etc/rc.d/S$padded$name"
      fi

      stop_line="$(grep -E '^STOP=[0-9]+' "$f" | head -n1 | cut -d= -f2 | tr -dc '0-9' || true)"
      if [ -n "$stop_line" ]; then
        padded="$(printf '%02d' "$stop_line")"
        ln -sf "../init.d/$name" "$out/root/etc/rc.d/K$padded$name"
      fi
    done

    for f in ${filesRoot}/etc/uci-defaults/*; do
      install -Dm0755 "$f" "$out/root/etc/uci-defaults/$(basename "$f")"
    done

    for f in ${filesRoot}/lib/router-*.sh; do
      install -Dm0644 "$f" "$out/root/lib/$(basename "$f")"
    done

    install -Dm0755 ${router-ui}/bin/router-ui                 $out/root/usr/bin/router-ui
    install -Dm0755 ${filesRoot}/usr/bin/router-ui-set-pin  $out/root/usr/bin/router-ui-set-pin

    for f in ${filesRoot}/usr/libexec/router-*; do
      install -Dm0755 "$f" "$out/root/usr/libexec/$(basename "$f")"
    done

    for f in ${filesRoot}/usr/share/luci/menu.d/*; do
      install -Dm0644 "$f" "$out/root/usr/share/luci/menu.d/$(basename "$f")"
    done

    for f in ${filesRoot}/usr/share/rpcd/acl.d/*; do
      install -Dm0644 "$f" "$out/root/usr/share/rpcd/acl.d/$(basename "$f")"
    done

    for f in ${filesRoot}/www/luci-static/resources/view/router/*; do
      install -Dm0644 "$f" "$out/root/www/luci-static/resources/view/router/$(basename "$f")"
    done

    ${lib.optionalString (routerTailscaleUci != null) ''
      install -Dm0644 ${routerTailscaleUci} $out/root/etc/config/router-tailscale
    ''}

    tar -C $out/root -czf $out/config-overlay.tar.gz .
    (cd $out && sha256sum config-overlay.tar.gz > config-overlay.tar.gz.sha256)
  ''
