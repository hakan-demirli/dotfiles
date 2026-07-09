{
  username ? "defaultName",
  ...
}:
{
  programs.firefox = {
    enable = true;
    profiles."${username}" = {
      search = {
        default = "ddg";
        force = true;
        engines = {
          "amazondotcom-us".metaData.hidden = true;
          "bing".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "wikipedia".metaData.hidden = true;

          "ddg" = {
            urls = [
              {
                template = "https://duckduckgo.com";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ ",d" ];
          };
          "google" = {
            urls = [
              {
                template = "https://google.com/search";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ ",go" ];
          };
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ ",np" ];
          };
          "youtube" = {
            urls = [
              {
                template = "https://www.youtube.com/results";
                params = [
                  {
                    name = "search_query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ ",yt" ];
          };
          "GitHub" = {
            urls = [
              {
                template = "https://github.com/search";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ ",gi" ];
          };
        };
      };

      isDefault = true;

      userChrome = builtins.readFile ../../config/firefoxcss/userChrome.css;
      userContent = builtins.readFile ../../config/firefoxcss/userContent.css;
      settings = {
        "browser.urlbar.suggest.trending" = false;
        "browser.urlbar.trimURLs" = false;

        "full-screen-api.transition-duration.enter" = "0 0";
        "full-screen-api.transition-duration.leave" = "0 0";
        "full-screen-api.warning.delay" = -1;
        "full-screen-api.warning.timeout" = 0;

        "browser.newtabpage.introShown" = false;
        "browser.urlbar.resultMenu.keyboardAccessible" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.tabs.tabmanager.enabled" = true;
        "network.trr.mode" = 2;
        "extensions.webextensions.restrictedDomains" = "";
        "privacy.resistFingerprinting.block_mozAddonManager" = true;
        "browser.translations.select.enable" = false;
        "browser.gesture.swipe.left" = "";
        "browser.gesture.swipe.right" = "";
        "app.normandy.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "browser.protections_panel.infoMessage.seen" = true;
        "dom.private-attribution.submission.enabled" = false;

        "beacon.enabled" = false;
        "device.sensors.enabled" = false;
        "geo.enabled" = false;

        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.server" = "";
        "toolkit.telemetry.unified" = false;
        "extensions.webcompat-reporter.enabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "browser.ping-centre.telemetry" = false;
        "browser.urlbar.eventTelemetry.enabled" = false;

        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
        "browser.compactmode.show" = true;
        "browser.toolbars.bookmarks.visibility" = "always";
        "browser.uidensity" = 1;
        "browser.download.autohideButton" = false;
        "ui.key.menuAccessKeyFocuses" = false;
        "ui.key.menuAccessKey" = 0;
        "findbar.highlightAll" = true;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.system.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.startup.page" = 3;
        "trailhead.firstrun.didSeeAboutWelcome" = true;
        "general.autoScroll" = true;
        "extensions.pocket.enabled" = false;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "browser.aboutConfig.showWarning" = false;
        browser.uiCustomization.state = ''
          {"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action","_ea4204c0-3209-4116-afd2-2a208e21a779_-browser-action","_531906d3-e22f-4a6c-a102-8057b88a1a63_-browser-action"],"nav-bar":["back-button","forward-button","customizableui-special-spring1","urlbar-container","stop-reload-button","customizableui-special-spring2","save-to-pocket-button","downloads-button","unified-extensions-button","_3c078156-979c-498b-8990-85f7987dd929_-browser-action","ublock0_raymondhill_net-browser-action","addon_darkreader_org-browser-action"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["firefox-view-button","tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["save-to-pocket-button","developer-button","_3c078156-979c-498b-8990-85f7987dd929_-browser-action","ublock0_raymondhill_net-browser-action","_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action","_ea4204c0-3209-4116-afd2-2a208e21a779_-browser-action","addon_darkreader_org-browser-action","_531906d3-e22f-4a6c-a102-8057b88a1a63_-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","unified-extensions-area"],"currentVersion":20,"newElementCount":3}
        '';
      };
    };
  };
}
