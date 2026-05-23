{
  flake.modules.nixos.system-amd-graphics =
    { pkgs, ... }:
    {
      boot.initrd.kernelModules = [ "amdgpu" ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      environment.systemPackages = with pkgs; [
        nvtopPackages.amd
        libva-utils
        vulkan-tools
      ];
    };
}
