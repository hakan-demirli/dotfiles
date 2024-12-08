{
  pkgs,
  config,
  ...
}:

let
  grafanaAddr = "127.0.0.1";
  grafanaPort = 5000;
  prometheusAddr = "127.0.0.1";
  prometheusPort = 9090;
  exporterAddr = "127.0.0.10";
  exporterTestPort = 8010;
  exporterSystemPort = 8011;
  exporterReviewPort = 8012;
  exporterNetworkPort = 8013;
  exporterWindowPort = 8014;
in
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = grafanaAddr;
        http_port = grafanaPort;
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
          name = "Prometheus";
          uid = "prometheus";
          type = "prometheus";
          url = "http://${prometheusAddr}:${toString prometheusPort}"; # Prometheus URL
          access = "proxy";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    listenAddress = prometheusAddr;
    port = prometheusPort;

    # double check on http://127.0.0.1:9090/status
    retentionTime = "100000d"; # Equivalent to ~273 years
    scrapeConfigs = [
      {
        job_name = "exporter_test";
        static_configs = [
          { targets = [ "${exporterAddr}:${toString exporterTestPort}" ]; }
        ];
      }
      {
        job_name = "exporter_system";
        static_configs = [
          { targets = [ "${exporterAddr}:${toString exporterSystemPort}" ]; }
        ];
      }
      {
        job_name = "exporter_review";
        static_configs = [
          { targets = [ "${exporterAddr}:${toString exporterReviewPort}" ]; }
        ];
      }
      {
        job_name = "exporter_network";
        static_configs = [
          { targets = [ "${exporterAddr}:${toString exporterNetworkPort}" ]; }
        ];
      }
      {
        job_name = "exporter_window";
        static_configs = [
          { targets = [ "${exporterAddr}:${toString exporterWindowPort}" ]; }
        ];
      }
    ];
  };

  # Export all to environment
  environment.sessionVariables = {
    EXPORTER_ADDR = exporterAddr;
    EXPORTER_TEST_PORT = toString exporterTestPort;
    EXPORTER_SYSTEM_PORT = toString exporterSystemPort;
    EXPORTER_NETWORK_PORT = toString exporterNetworkPort;
    EXPORTER_REVIEW_PORT = toString exporterReviewPort;
    EXPORTER_WINDOW_PORT = toString exporterWindowPort;
    GRAFANA_ADDR = grafanaAddr;
    GRAFANA_PORT = toString grafanaPort;
    PROMETHEUS_ADDR = prometheusAddr;
    PROMETHEUS_PORT = toString prometheusPort;
  };
  environment.systemPackages = [ pkgs.prometheus ];
}
