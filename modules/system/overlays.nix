{
  lib,
  host ? null,
  ...
}:
let
  hwGpu = if host == null then null else (host.hardware.gpu or null);
  hasNvidia = hwGpu != null && (builtins.match ".*nvidia.*" hwGpu) != null;

  pythonTritonOverlay = _final: prev: {
    python312 =
      if prev.stdenv.isLinux then
        prev.python312.override {
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
        }
      else
        prev.python312;
  };
in
{
  nixpkgs.overlays = lib.optional hasNvidia pythonTritonOverlay;
}
