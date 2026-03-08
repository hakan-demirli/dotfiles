{
  flake.modules.darwin.macbook = {
    users.users.alice = {
      name = "alice";
      home = "/Users/alice";
    };
    home-manager.users.alice = {
      home.stateVersion = "24.11";
    };
  };
}
