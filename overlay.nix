{
  config,
  pkgs,
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    # https://github.com/NixOS/nixpkgs/issues/351717
    (final: prev: {
      python312 = prev.python312.override {
        packageOverrides = final: prevPy: {

          triton-bin = prevPy.triton-bin.overridePythonAttrs (oldAttrs: {
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
  ];
}
