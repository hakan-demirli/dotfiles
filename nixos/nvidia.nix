# https://nixos.wiki/wiki/Nvidia
{
  config,
  pkgs,
  ...
}: let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in {
  environment.systemPackages = [nvidia-offload];
  services.xserver.videoDrivers = ["nvidia"];

  hardware.opengl.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false; # Use the open source version? nope
    nvidiaSettings = true; # 	accessible via `nvidia-settings`.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      # Bus IDs of the  GPUs. Find it using lspci, either under 3D or VGA
      # 'pciutils' package has lspci command.
      # 06:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Renoir (rev c6)
      amdgpuBusId = "PCI:6:0:0";
      # 01:00.0 VGA compatible controller: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti Mobile] (rev a1)
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
