{
  flake.modules = {
    generic.overlays = {
      nixpkgs.overlays = [
        (final: prev: {
          # https://github.com/NixOS/nixpkgs/pull/507484 (not yet in nixos-unstable)
          # Bypass the deprecated `pkgs.hostPlatform` warning emitted when
          # packages like flutter auto-inject it via callPackage.
          inherit (prev.stdenv) hostPlatform;

          # https://github.com/NixOS/nixpkgs/issues/351717
          python312 = prev.python312.override {
            packageOverrides =
              _: prevPy:
              if prev.stdenv.isLinux then
                {
                  triton-bin = prevPy.triton-bin.overridePythonAttrs (_: {
                    postFixup = ''
                      chmod +x "$out/${prev.python312.sitePackages}/triton/backends/nvidia/bin/ptxas"
                      substituteInPlace $out/${prev.python312.sitePackages}/triton/backends/nvidia/driver.py \
                        --replace \
                          'return [libdevice_dir, *libcuda_dirs()]' \
                          'return [libdevice_dir, "${prev.addDriverRunpath.driverLink}/lib", "${prev.cudaPackages.cuda_cudart}/lib/stubs/"]'
                    '';
                  });
                }
              else
                { };
          };
          python312Packages = final.python312.pkgs;

          # https://github.com/anomalyco/opencode/pull/14743
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
                ../../../pkgs/opencode-cache-fixes.patch
                ../../../pkgs/opencode-continue-dummy-toast.patch
                ../../../pkgs/opencode-attach-event-scope.patch
              ];
              node_modules = oldAttrs.node_modules.overrideAttrs (_: {
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
                outputHash = "sha256-R929GTFSKntPaGf5gRizfVhKdYFJyDc9u9/SSlQu6XE=";
              });

              postInstall = (oldAttrs.postInstall or "") + ''
                wrapProgram $out/bin/opencode \
                  --set OPENCODE_CACHE_AUDIT 1 \
                  --set OPENCODE_EXPERIMENTAL_CACHE_STABILIZATION 1 \
                  --set OPENCODE_EXPERIMENTAL_CACHE_1H_TTL 0
              '';
            }
          );

          # https://github.com/NixOS/nixpkgs/issues/409755#issuecomment-2931205330
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
        })
      ];
    };

    nixos.overlays =
      { inputs, ... }:
      {
        imports = [ inputs.self.modules.generic.overlays ];
      };

    darwin.overlays =
      { inputs, ... }:
      {
        imports = [ inputs.self.modules.generic.overlays ];
      };

    homeManager.overlays =
      { inputs, ... }:
      {
        imports = [ inputs.self.modules.generic.overlays ];
      };
  };
}
