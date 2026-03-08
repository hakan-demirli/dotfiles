_: {
  flake.modules.darwin.macbook = {
    networking.hostName = "macbook";

    system.stateVersion = 6;
    system.primaryUser = "bob";

    homebrew = {
      enable = true;
      masApps = {
        "Numbers" = 409203825;
        "Pages" = 409201541;
        "Keynote" = 409183694;
        "iMovie" = 408981434;
      };
    };
  };
}
