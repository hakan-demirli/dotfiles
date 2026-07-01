{
  hasNvidia ? false,
}:
final: prev:
let
  callPkgs = path: extra: final.callPackage path ({ pkgs = final; } // extra);
in
(prev.lib.optionalAttrs (hasNvidia && prev.stdenv.isLinux) {
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
  opencode = prev.opencode.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "43b51f09-cache-fixes";
      src = prev.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opencode";
        rev = "2662a4f955e563fd22cd5c4873ca350d21745275";
        hash = "sha256-qVkOgLXUU/vaWDZIkBeR3Fhkcz7cPshpyQIkuxwKUEM=";
      };
      patches = (oldAttrs.patches or [ ]) ++ [
        ./patches/opencode-cache-fixes.patch
        ./patches/opencode-continue-dummy-toast.patch
        ./patches/opencode-attach-event-scope.patch
      ];
      node_modules =
        if oldAttrs ? node_modules then
          oldAttrs.node_modules.overrideAttrs (_: {
            version = "43b51f09-cache-fixes";
            inherit (finalAttrs) src;
            buildPhase = ''
              runHook preBuild

              bun install \
                --cpu="*" \
                --filter ./packages/app \
                --filter ./packages/desktop \
                --filter ./packages/opencode \
                --filter ./packages/ui \
                --ignore-scripts \
                --no-progress \
                --os="*"

              bun --bun ./nix/scripts/canonicalize-node-modules.ts
              bun --bun ./nix/scripts/normalize-bun-binaries.ts

              runHook postBuild
            '';
            outputHash = "sha256-w8yHW5UebW6O5I1zVTdMTmcMJ7MkdLILhwWyMYoHlMg=";
          })
        else
          (oldAttrs.node_modules or null);

      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/opencode \
          --set OPENCODE_CACHE_AUDIT 1 \
          --set OPENCODE_EXPERIMENTAL_CACHE_STABILIZATION 1 \
          --set OPENCODE_EXPERIMENTAL_CACHE_1H_TTL 0
      '';
    }
  );

  blender-emre = callPkgs ./blender.nix { };
  deasciifier = callPkgs ./deasciifier.nix { };
  gparted-emre = callPkgs ./gparted.nix { };
  helix-emre = final.callPackage ./helix.nix { };
  j4-dmenu-desktop-emre = final.callPackage ./j4-dmenu-desktop.nix { };
  libqalculate-fzf = callPkgs ./libqalculate-fzf.nix { };
  mitype = callPkgs ./mitype.nix { };
  noisereduce = callPkgs ./noisereduce.nix { };
  pedalboard = callPkgs ./pedalboard.nix { };
  rvc-cli = callPkgs ./rvc-cli.nix { };
  svlangserver = callPkgs ./svlangserver.nix { };
  ttf-wps-fonts = callPkgs ./ttf-wps-fonts.nix { };

  kooha =
    if prev.stdenv.isLinux then
      prev.kooha.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [
          prev.gst_all_1.gst-plugins-bad
          prev.gst_all_1.gst-vaapi
        ];
      })
    else
      prev.kooha;

  python3Packages = prev.python3Packages.overrideScope (
    pyFinal: _pyPrev: {
      local-attention = pyFinal.callPackage ./local-attention.nix { };
    }
  );

  perlPackages = prev.perlPackages.overrideScope (
    _pSelf: pSuper: {
      DBDCSV = pSuper.DBDCSV.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (prev.fetchpatch2 {
            name = "dbd-csv-0.60-dbi.patch";
            url = "https://github.com/perl5-dbi/DBD-CSV/commit/ae091790398088a66b22fa572856bfeb4db4c78a.patch";
            hash = "sha256-d3k7H6gFXCsRGR3QPXCwqtL1+IXRv582P59FMtinTbE=";
            includes = [
              "t/70_csv.t"
              "t/lib.pl"
            ];
          })
        ];
      });
    }
  );
}
