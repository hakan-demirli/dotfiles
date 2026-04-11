{ inputs, ... }:
{
  flake.modules.darwin.macbook = {
    users.users.bob = {
      name = "bob";
      home = "/Users/bob";
    };
    home-manager.users.bob = {
      home.stateVersion = inputs.self.lib.stateVersion;
    };
  };
}
