_: {
  nixpkgs.overlays = [
    # https://github.com/NixOS/nixpkgs/issues/351717
    (final: prev: {
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

      # https://github.com/NixOS/nixpkgs/issues/409755#issuecomment-2931205330
      kooha = prev.kooha.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [
          prev.gst_all_1.gst-plugins-bad
          prev.gst_all_1.gst-vaapi
        ];
      });

    })
  ];
}
