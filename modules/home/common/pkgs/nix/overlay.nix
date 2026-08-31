{
  hasNvidia ? false,
}:
final: prev:
let
  callPkgs = path: extra: final.callPackage path ({ pkgs = final; } // extra);
in
(prev.lib.optionalAttrs (hasNvidia && prev.stdenv.hostPlatform.isLinux) {
  python312 = prev.python312.override {
    packageOverrides = _: prevPy: {
      triton-bin = prevPy.triton-bin.overridePythonAttrs (_: {
        postFixup = ''
          chmod +x "$out/${prev.python312.sitePackages}/triton/backends/nvidia/bin/ptxas"
          substituteInPlace $out/${prev.python312.sitePackages}/triton/backends/nvidia/driver.py \
            --replace \
              'return [libdevice_dir, *libcuda_dirs()]' \
              'return [libdevice_dir, "${prev.addDriverRunpath.driverLink}/lib", "${prev.cudaPackages.cuda_cudart}/lib/stubs/"]'
        '';
      });
    };
  };
  python312Packages = final.python312.pkgs;
})
// {
  # https://github.com/NixOS/nixpkgs/pull/548380
  dracula-theme =
    let
      themeName = "Dracula";
    in
    final.stdenvNoCC.mkDerivation {
      pname = "dracula-theme";
      version = "4.0.0-unstable-2026-03-01";

      __structuredAttrs = true;
      strictDeps = true;

      src = final.fetchFromGitHub {
        owner = "dracula";
        repo = "gtk";
        rev = "1188c8eabdfc33c42738862b91caf7fab884c767";
        hash = "sha256-Z3dMgkk5SvpCWjxdm8hd5FBeEvq0uCJuj3zC5boQEdk=";
      };

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/themes/${themeName}
        cp -a {assets,cinnamon,gnome-shell,gtk-3.0,gtk-3.20,gtk-4.0,index.theme,metacity-1,unity,xfwm4} $out/share/themes/${themeName}

        cp -a kde/{color-schemes,plasma} $out/share/
        cp -a kde/kvantum $out/share/Kvantum
        mkdir -p $out/share/aurorae/themes
        cp -a kde/aurorae/* $out/share/aurorae/themes/
        mkdir -p $out/share/sddm/themes
        cp -a kde/sddm/* $out/share/sddm/themes/

        mkdir -p $out/share/icons/Dracula-cursors
        mv kde/cursors/Dracula-cursors/index.theme $out/share/icons/Dracula-cursors/cursor.theme
        mv kde/cursors/Dracula-cursors/cursors $out/share/icons/Dracula-cursors/cursors

        runHook postInstall
      '';

      passthru.updateScript = final.unstableGitUpdater {
        tagPrefix = "v";
      };

      meta = {
        description = "Dracula variant of the Ant theme";
        homepage = "https://github.com/dracula/gtk";
        license = final.lib.licenses.gpl3;
        platforms = final.lib.platforms.all;
        maintainers = with final.lib.maintainers; [ alexarice ];
      };
    };
  # opencode = prev.opencode.overrideAttrs (
  #   finalAttrs: oldAttrs: {
  #     version = "43b51f09-cache-fixes";
  #     src = prev.fetchFromGitHub {
  #       owner = "anomalyco";
  #       repo = "opencode";
  #       rev = "2662a4f955e563fd22cd5c4873ca350d21745275";
  #       hash = "sha256-qVkOgLXUU/vaWDZIkBeR3Fhkcz7cPshpyQIkuxwKUEM=";
  #     };
  #     patches = (oldAttrs.patches or [ ]) ++ [
  #       ./patches/opencode-cache-fixes.patch
  #       ./patches/opencode-continue-dummy-toast.patch
  #       ./patches/opencode-attach-event-scope.patch
  #     ];
  #     node_modules =
  #       if oldAttrs ? node_modules then
  #         oldAttrs.node_modules.overrideAttrs (_: {
  #           version = "43b51f09-cache-fixes";
  #           inherit (finalAttrs) src;
  #           buildPhase = ''
  #             runHook preBuild
  #
  #             bun install \
  #               --cpu="*" \
  #               --filter ./packages/app \
  #               --filter ./packages/desktop \
  #               --filter ./packages/opencode \
  #               --filter ./packages/ui \
  #               --ignore-scripts \
  #               --no-progress \
  #               --os="*"
  #
  #             bun --bun ./nix/scripts/canonicalize-node-modules.ts
  #             bun --bun ./nix/scripts/normalize-bun-binaries.ts
  #
  #             runHook postBuild
  #           '';
  #           outputHash = "sha256-w8yHW5UebW6O5I1zVTdMTmcMJ7MkdLILhwWyMYoHlMg=";
  #         })
  #       else
  #         (oldAttrs.node_modules or null);
  #
  #     postInstall = (oldAttrs.postInstall or "") + ''
  #       wrapProgram $out/bin/opencode \
  #         --set OPENCODE_CACHE_AUDIT 1 \
  #         --set OPENCODE_EXPERIMENTAL_CACHE_STABILIZATION 1 \
  #         --set OPENCODE_EXPERIMENTAL_CACHE_1H_TTL 0
  #     '';
  #   }
  # );

  libqalculate-fzf = callPkgs ./libqalculate-fzf.nix { };
  oskd = callPkgs ./oskd.nix { };
  ttf-wps-fonts = callPkgs ./ttf-wps-fonts.nix { };
}
