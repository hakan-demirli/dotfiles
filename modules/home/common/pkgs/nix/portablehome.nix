{ pkgs }:
let
  inherit (pkgs) lib;
  ps = pkgs.pkgsStatic;

  staticBins = [
    ps.ripgrep
    ps.fd
    ps.bat
    ps.fzf
    ps.jq
    ps.tree
    ps.delta
    ps.starship
    ps.htop
    ps.tmux
    ps.yek
    ps.ouch
    ps.unzip
    ps.zip
  ];

  scriptsSrc = ../bin;
  configSrc = ../../config;
  deploySrc = ./portablehome-deploy.sh;
in
pkgs.runCommand "portablehome"
  {
    passthru = {
      inherit staticBins;
      binNames = map (p: p.pname or p.name) staticBins;
    };
    meta = {
      description = "Portable dotfiles bundle for nix-less linux hosts.";
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/bin $out/scripts $out/config

    ${lib.concatMapStringsSep "\n" (p: ''
      if [ -d ${p}/bin ]; then
        for f in ${p}/bin/*; do
          bn="$(basename "$f")"
          if [ ! -e "$out/bin/$bn" ]; then
            cp -a "$f" "$out/bin/$bn"
          else
            echo "portablehome: skipping duplicate $bn from ${p.pname or p.name}"
          fi
        done
      fi
    '') staticBins}

    chmod -R u+w $out/bin
    for f in $out/bin/*; do
      [ -f "$f" ] || continue
      first="$(head -n1 "$f" 2>/dev/null || true)"
      case "$first" in
        "#!"*/nix/store/*|"#! "*/nix/store/*)
          interp="$(printf '%s' "$first" | sed -E 's|^#! *(/nix/store/[^ ]+)(.*)$|\1|')"
          args="$(printf '%s' "$first" | sed -E 's|^#! *(/nix/store/[^ ]+)(.*)$|\2|')"
          case "$interp" in
            */bash) new_shebang="#!/usr/bin/env bash$args" ;;
            */sh)   new_shebang="#!/bin/sh$args" ;;
            *)      new_shebang="$first" ;;
          esac
          if [ "$new_shebang" != "$first" ]; then
            tail -n +2 "$f" > "$f.tmp"
            { printf '%s\n' "$new_shebang"; cat "$f.tmp"; } > "$f"
            rm "$f.tmp"
            chmod a+rx "$f"
            echo "portablehome: rewrote shebang in $(basename "$f") ($first -> $new_shebang)"
          fi
          ;;
      esac
    done

    cp -a ${scriptsSrc}/. $out/scripts/
    chmod -R u+w $out/scripts
    find $out/scripts -type f -exec chmod a+rx {} +

    cp -a ${configSrc}/. $out/config/
    chmod -R u+w $out/config

    cp ${deploySrc} $out/deploy.sh
    chmod +x $out/deploy.sh
  ''
