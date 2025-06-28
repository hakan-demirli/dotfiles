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

      # https://github.com/NixOS/nixpkgs/pull/398248
      bindfs = prev.bindfs.overrideAttrs (oldAttrs: {
        pname = "bindfs";
        version = "1.18.1";

        src = prev.fetchurl {
          url = "https://bindfs.org/downloads/bindfs-1.18.1.tar.gz";
          hash = "sha256-KnBk2ZOl8lXFLXI4XvFONJwTG8RBlXZuIXNCjgbSef0=";
        };

        # This adds the reverted patch. Using `(oldAttrs.patches or []) ++` is a
        # safe way to add patches, even if the original package had none.
        patches = (oldAttrs.patches or [ ]) ++ [
          (prev.fetchpatch {
            url = "https://github.com/mpartel/bindfs/commit/3293dc98e37eed0fb0cbfcbd40434d3c37c69480.patch";
            hash = "sha256-dtjvSJTS81R+sksl7n1QiyssseMQXPlm+LJYZ8/CESQ=";
            revert = true;
          })
        ];

        # The diff adds autoreconfHook, so we append it to the existing nativeBuildInputs.
        nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ prev.autoreconfHook ];
      });

    })
  ];
}
