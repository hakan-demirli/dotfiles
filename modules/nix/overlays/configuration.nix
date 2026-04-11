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

          claude-code = import ../../../pkgs/claude-code.nix prev;

          # https://github.com/anomalyco/opencode/pull/14743
          opencode = prev.opencode.overrideAttrs (
            finalAttrs: oldAttrs: {
              version = "pr-14743";
              src = prev.fetchFromGitHub {
                owner = "anomalyco";
                repo = "opencode";
                rev = "refs/pull/14743/head";
                hash = "sha256-E6Z04kkmyku47Y4Oo7fH/idcLzIpJhH1XGFIBIczVro=";
              };
              node_modules = oldAttrs.node_modules.overrideAttrs (_: {
                version = "pr-14743";
                inherit (finalAttrs) src;
                outputHash = "sha256-K6wRsvkhKzNL727/nqAUedv0HvfJt7vu13RKKcJ9adk=";
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
