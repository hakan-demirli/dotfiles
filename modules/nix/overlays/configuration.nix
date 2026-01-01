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

          # https://github.com/NixOS/nixpkgs/pull/475790
          udevil = prev.udevil.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or [ ]) ++ [
              (prev.writeText "udevil-fix-gcc15.patch" ''
                diff --git a/src/udevil.c b/src/udevil.c
                index bab80e9..f9e5388 100644
                --- a/src/udevil.c
                +++ b/src/udevil.c
                @@ -4795,7 +4795,7 @@ static int command_info( CommandData* data )
                     return ret;
                 }
                 
                -void command_monitor_finalize()
                +void command_monitor_finalize(int _a)
                 {
                     //if (signal == SIGINT || signal == SIGTERM)
                     //printf( "\nudevil: SIGINT || SIGTERM\n");
                @@ -4913,7 +4913,7 @@ finish_:
                     return 1;
                 }
                 
                -void command_interrupt()
                +void command_interrupt(int _a)
                 {
                     if ( udev )
                     {
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
