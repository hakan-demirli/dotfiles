{
  flake.modules = {
    generic.overlays = {
      nixpkgs.overlays = [
        (final: prev: {
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

          nwg-displays = prev.nwg-displays.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or [ ]) ++ [
              (prev.writeText "nwg-displays-fix-import.patch" ''
                diff --git a/nwg_displays/main.py b/nwg_displays/main.py
                index 22da645..08407c9 100644
                --- a/nwg_displays/main.py
                +++ b/nwg_displays/main.py
                @@ -16,6 +16,7 @@ Thank you, Kurt Jacobson!
                 import argparse
                 import os.path
                 import sys
                +import stat
                 
                 import gi
              '')
            ];
          });
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
