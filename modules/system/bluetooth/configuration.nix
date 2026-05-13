{
  flake.modules.nixos.system-bluetooth = _: {
    services.blueman.enable = true;

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings = {
        General = {
          ControllerMode = "dual";
          FastConnectable = "true";
          Experimental = "true";
          KernelExperimental = "true";
        };
        Policy = {
          AutoEnable = "false";
        };
      };
    };
  };
}
