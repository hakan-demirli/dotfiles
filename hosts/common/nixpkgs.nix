{
  cudaSupport ? false, # ok times with cachix
  rocmSupport ? false,
  ...
}:
{
  nixpkgs.config = {
    allowUnfree = true;
    inherit rocmSupport cudaSupport;
    allowUnfreePredicate =
      p:
      builtins.all (
        license:
        license.free
        || builtins.elem license.shortName [
          "CUDA EULA"
          "cuDNN EULA"
          "cuTENSOR EULA"
          "NVidia OptiX EULA"
        ]
      ) (if builtins.isList p.meta.license then p.meta.license else [ p.meta.license ]);
  };
}
