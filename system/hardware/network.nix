{
  pkgs,
  userSettings,
  systemSettings,
  ...
}: {
  # Enable networking
  networking = {
    hostName = systemSettings.hostname; # Define your hostname.

    networkmanager = {
      enable = true;
      # dns = "systemd-resolved";
    };

    extraHosts = ''
      0.0.0.0  9gag.com
      0.0.0.0  www.9gag.com
      0.0.0.0  reddit.com
      0.0.0.0  www.reddit.com
    '';
  };

  services = {
    openssh = {
      enable = true;
      settings.UseDns = true;
    };

    # DNS resolver
    resolved.enable = false;
    # resolved = {
    #   enable = true;
    #   dnsovertls = "opportunistic";
    # };

    # encrypted dns
    dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        require_dnssec = true;

        dnscrypt_servers = true;
        doh_servers = true;

        sources.public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        };
      };
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1; # required to share your internet
    # "net.ipv6.conf.all.forwarding" = 1;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
}
