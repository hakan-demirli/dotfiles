{
  flake.modules.nixos.services-yubikey =
    { pkgs, inputs, ... }:
    let
      yubicoPackages = builtins.attrValues {
        inherit (pkgs)
          yubikey-manager
          yubico-piv-tool
          yubioath-flutter
          pam_u2f
          ;
      };
      publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
    in
    {
      services.pcscd.enable = true;
      services.udev.packages = yubicoPackages;
      environment.systemPackages = yubicoPackages;

      security.pam.u2f = {
        enable = true;
        settings = {
          cue = true;
          control = "sufficient";
          authfile = pkgs.writeText "u2f_keys" publicData.yubikey.u2fkey;
        };
      };

      security.pam.services = {
        sudo.u2fAuth = true;
        hyprlock.u2fAuth = false;
        sddm.u2fAuth = false;
        login.u2fAuth = false;
      };
    };
}
