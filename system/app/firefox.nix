{
  pkgs,
  userSettings,
  ...
}: {
  programs.firefox = {
    enable = true;
    profiles."${userSettings.username}" = {
      # extensions = with pkgs.nur.repos.rycee.firefox-addons; []; # handled by firefox account

      search.default = "Google";
      search.force = true;
      isDefault = true;

      userChrome = builtins.readFile ../../.config/firefoxcss/userChrome.css;
      userContent = builtins.readFile ../../.config/firefoxcss/userContent.css;
      settings = {
        # Prevent tabbing on the "3 dot menu" on Firefox Suggest drop down items
        # https://connect.mozilla.org/t5/discussions/how-to-remove-the-3-dot-menu-on-firefox-suggest-drop-down-items/td-p/28339
        "browser.urlbar.resultMenu.keyboardAccessible" = false;
        # "widget.use-xdg-desktop-portal.file-picker" = 1;
        "network.trr.mode" = 2; # DOH
        # enable extensions in mozilla sites
        "extensions.webextensions.restrictedDomains" = "";
        "privacy.resistFingerprinting.block_mozAddonManager" = true;

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
        # To change: Customize ui, copy it from about:config and paste here.
        browser.uiCustomization.state = ''          {"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action","_ea4204c0-3209-4116-afd2-2a208e21a779_-browser-action","_531906d3-e22f-4a6c-a102-8057b88a1a63_-browser-action"],"nav-bar":["back-button","forward-button","customizableui-special-spring1","urlbar-container","stop-reload-button","customizableui-special-spring2","save-to-pocket-button","downloads-button","unified-extensions-button","_3c078156-979c-498b-8990-85f7987dd929_-browser-action","ublock0_raymondhill_net-browser-action","addon_darkreader_org-browser-action"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["firefox-view-button","tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["save-to-pocket-button","developer-button","_3c078156-979c-498b-8990-85f7987dd929_-browser-action","ublock0_raymondhill_net-browser-action","_7be2ba16-0f1e-4d93-9ebc-5164397477a9_-browser-action","_ea4204c0-3209-4116-afd2-2a208e21a779_-browser-action","addon_darkreader_org-browser-action","_531906d3-e22f-4a6c-a102-8057b88a1a63_-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","unified-extensions-area"],"currentVersion":20,"newElementCount":3}
        '';
      };
    };
  };
}
