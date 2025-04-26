{
  allowPasswordAuth ? false,
  rootSshKeys ? [ ],
  ...
}:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = allowPasswordAuth;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
      UsePAM = true;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = rootSshKeys;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
