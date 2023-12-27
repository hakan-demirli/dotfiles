{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    profiles.emre = {
      # extensions = with pkgs.nur.repos.rycee.firefox-addons; []; # handled by firefox account

      search.default = "Google";
      search.force = true;
      isDefault = true;

      userChrome = builtins.readFile ../.config/firefoxcss/userChrome.css;
      userContent = builtins.readFile ../.config/firefoxcss/userContent.css;
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
        "browser.compactmode.show" = true;
        "browser.toolbars.bookmarks.visibility" = "never";
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
        "browser.startup.page" = 3; # restore previous session
        "trailhead.firstrun.didSeeAboutWelcome" = true; # Disable welcome splash
        "general.autoScroll" = true; # Drag middle-mouse to scroll
        "extensions.pocket.enabled" = false;
        "media.ffmpeg.vaapi.enabled" = true; # Enable hardware video acceleration
        "browser.aboutConfig.showWarning" = false;
      };
    };
  };
}
