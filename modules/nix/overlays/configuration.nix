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
          # Pinned to a specific commit SHA (not refs/pull/14743/head) so upstream
          # pushes to the PR branch don't silently change the build inputs.
          opencode = prev.opencode.overrideAttrs (
            finalAttrs: oldAttrs: {
              version = "pr-14743";
              src = prev.fetchFromGitHub {
                owner = "bhagirathsinh-vaghela";
                repo = "opencode";
                rev = "2e02781f4f6e61f8c673bc669e982810dc0268c1";
                hash = "sha256-E6Z04kkmyku47Y4Oo7fH/idcLzIpJhH1XGFIBIczVro=";
              };
              node_modules = oldAttrs.node_modules.overrideAttrs (_: {
                version = "pr-14743";
                inherit (finalAttrs) src;
                # Upstream PR has an inconsistent bun.lock, so we can't use
                # --frozen-lockfile. Let bun update the lockfile at build time.
                buildPhase = ''
                  runHook preBuild

                  bun install \
                    --cpu="*" \
                    --filter ./packages/app \
                    --filter ./packages/desktop \
                    --filter ./packages/opencode \
                    --ignore-scripts \
                    --no-progress \
                    --os="*"

                  bun --bun ./nix/scripts/canonicalize-node-modules.ts
                  bun --bun ./nix/scripts/normalize-bun-binaries.ts

                  runHook postBuild
                '';
                outputHash = "sha256-/5tUPT885z7uJBh80WXj/69G86zg3Be1LjlhgRD9Ico=";
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
