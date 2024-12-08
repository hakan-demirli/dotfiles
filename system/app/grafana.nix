{
  config,
  pkgs,
  ...
}:
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.69";
        http_port = 5000;
      };

      "auth.anonymous" = {
        enabled = true;
        org_role = "Admin";
      };

      panels = {
        disable_sanitize_html = true;
      };
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Influx";
          uid = "influx";
          type = "influxdb";
          access = "proxy";
          url = "http://127.0.0.1:8086";
          jsonData = {
            defaultBucket = "localdata";
            organization = "local";
            httpMode = "POST";
            version = "Flux";
          };
          secureJsonData = {
            token = "your-local-token";
          };
        }
      ];
    };
  };

  services.influxdb2 = {
    enable = true;
    provision = {
      enable = true;

      initialSetup = {
        bucket = "localdata";
        username = "local";
        organization = "local";

        retention = 7 * 24 * 60 * 60;

        tokenFile = "/path/to/your/token/file"; # Replace with a real path
        passwordFile = "/path/to/your/password/file"; # Replace with a real path
      };
    };
  };
}
