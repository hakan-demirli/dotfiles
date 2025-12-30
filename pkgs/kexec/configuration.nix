{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/netboot/netboot.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # stripped down version of https://github.com/cleverca22/nix-tests/tree/master/kexec
  system.build = rec {
    image = pkgs.runCommand "image" { buildInputs = [ pkgs.nukeReferences ]; } ''
      mkdir $out
      cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} $out/kernel
      cp ${config.system.build.netbootRamdisk}/initrd $out/initrd
      nuke-refs $out/kernel
    '';
    kexec_script = pkgs.writeTextFile {
      executable = true;
      name = "kexec-nixos";
      text = ''
        #!${pkgs.stdenv.shell}
        set -e
        ${pkgs.kexec-tools}/bin/kexec -l ${image}/kernel --initrd=${image}/initrd --append="init=${builtins.unsafeDiscardStringContext config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
        sync
        echo "executing kernel, filesystems will be improperly umounted"
        ${pkgs.kexec-tools}/bin/kexec -e
      '';
    };
    kexec_tarball = pkgs.callPackage (modulesPath + "/../lib/make-system-tarball.nix") {
      storeContents = [
        {
          object = config.system.build.kexec_script;
          symlink = "/kexec_nixos";
        }
      ];
      contents = [ ];
      compressCommand = "cat";
      compressionExtension = "";
    };
    kexec_tarball_self_extract_script = pkgs.writeTextFile {
      executable = true;
      name = "kexec-nixos";
      text = ''
        #!/bin/sh
        set -eu
        ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ { print NR + 1; exit 0; }' $0`
        tail -n+$ARCHIVE $0 | tar x -C /
        /kexec_nixos $@
        exit 1
        __ARCHIVE_BELOW__
      '';
    };
    kexec_bundle = pkgs.runCommand "kexec_bundle" { } ''
      cat \
        ${kexec_tarball_self_extract_script} \
        ${kexec_tarball}/tarball/nixos-system-${kexec_tarball.system}.tar \
        > $out
      chmod +x $out
    '';
  };

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
    ];
    kernelParams = [
      "panic=30"
      "boot.panic_on_fail" # reboot the machine upon fatal boot issues
      "console=ttyS0" # enable serial console
      "console=tty1"
    ];
    kernel.sysctl."vm.overcommit_memory" = "1";
  };
  environment.systemPackages = with pkgs; [ cryptsetup ];
  environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

  networking.hostName = "kexec";

  services = {
    getty.autologinUser = "root";
    openssh = {
      enable = true;
      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
      };
    };
    udisks2.enable = false;
  };

  documentation.enable = false;
  documentation.nixos.enable = false;
  fonts.fontconfig.enable = false;
  programs.bash.completion.enable = false;
  programs.command-not-found.enable = false;
  security.polkit.enable = false;
  security.rtkit.enable = pkgs.lib.mkForce false;
  i18n.supportedLocales = [ (config.i18n.defaultLocale + "/UTF-8") ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me"
  ];
}
