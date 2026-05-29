-- Variables, autostart, environment, visual config, input settings.
-- Replaces includes.conf.

---------------------
---- MY PROGRAMS ----
---------------------

terminal    = "kitty"
browser     = "MOZ_ENABLE_WAYLAND=1 firefox"
launcher    = "pkill tofi || tofi-drun --drun-launch=true"
filemanager = "lf_cd_hyprland" -- yazi_cd_hyprland
editor      = "hx"
locker      = "hyprlock"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("xremap ~/.config/xremap/config.yml")
    hl.exec_cmd("tailscale-systray")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("waybar")
    hl.exec_cmd("awww-daemon") -- wallpaper daemon
    hl.exec_cmd("gtk_applet_script_menu")
    hl.exec_cmd("update_wp")
    hl.exec_cmd("auto_refresh")
    hl.exec_cmd("hibat-collector")

    hl.exec_cmd("systemctl start --user polkit-gnome-authentication-agent-1")
    hl.exec_cmd("hypridle &")

    -- Share picker / portal integration
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("systemctl --user import-environment PATH && systemctl --user restart xdg-desktop-portal.service")

    hl.exec_cmd("firefox")
    hl.exec_cmd("kitty tmux_home.sh")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("EDITOR", editor)
hl.env("TERMINAL", "kitty")
hl.env("OPENER", "xdg-open")
hl.env("XCURSOR_SIZE", "24")
hl.env("WLR_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

local HOME = os.getenv("HOME")
local XDG_DATA_HOME   = os.getenv("XDG_DATA_HOME")   or (HOME .. "/.local/share")
local XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")
local XDG_STATE_HOME  = os.getenv("XDG_STATE_HOME")  or (HOME .. "/.local/state")
local XDG_CACHE_HOME  = os.getenv("XDG_CACHE_HOME")  or (HOME .. "/.cache")

hl.env("XDG_DATA_HOME",   XDG_DATA_HOME)
hl.env("XDG_CONFIG_HOME", XDG_CONFIG_HOME)
hl.env("XDG_STATE_HOME",  XDG_STATE_HOME)
hl.env("XDG_CACHE_HOME",  XDG_CACHE_HOME)
hl.env("PATH", table.concat({
    HOME .. "/.local/bin",
    "/run/wrappers/bin",
    HOME .. "/.nix-profile/bin",
    "/nix/profile/bin",
    HOME .. "/.local/state/nix/profile/bin",
    "/etc/profiles/per-user/" .. (os.getenv("USER") or "") .. "/bin",
    "/nix/var/nix/profiles/default/bin",
    "/run/current-system/sw/bin",
    "/usr/local/bin",
}, ":"))

hl.env("ANDROID_HOME",          XDG_DATA_HOME .. "/android")
hl.env("CARGO_HOME",            XDG_DATA_HOME .. "/cargo")
hl.env("CUDA_CACHE_PATH",       XDG_CACHE_HOME .. "/nv")
hl.env("GNUPGHOME",             XDG_DATA_HOME .. "/gnupg")
hl.env("PASSWORD_STORE_DIR",    XDG_DATA_HOME .. "/password-store")
hl.env("RUSTUP_HOME",           XDG_DATA_HOME .. "/rustup")
hl.env("NUGET_PACKAGES",        XDG_CACHE_HOME .. "/NuGetPackages")
hl.env("NPM_CONFIG_USERCONFIG", XDG_CONFIG_HOME .. "/npm/npmrc")
hl.env("DOTNET_CLI_HOME",       "/tmp/DOTNET_CLI_HOME")
hl.env("WGETRC",                XDG_CONFIG_HOME .. "/wgetrc")
hl.env("KIVY_HOME",             XDG_CONFIG_HOME .. "/kivy")
hl.env("PYTHONPYCACHEPREFIX",   XDG_CACHE_HOME .. "/python")
hl.env("PYTHONUSERBASE",        XDG_DATA_HOME .. "/python")
hl.env("GOPATH",                XDG_CACHE_HOME .. "/go")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    ecosystem = {
        no_update_news = true,
    },

    general = {
        border_size             = 2,
        gaps_in                 = 3,
        gaps_out                = 3,
        col = {
            active_border   = "rgba(f9deffff)",
            inactive_border = "rgba(595959aa)",
        },
        layout                  = "dwindle",
        extend_border_grab_area = true,
        hover_icon_on_border    = true,
    },

    decoration = {
        rounding = 5,

        blur = {
            enabled           = true,
            size              = 2,
            passes            = 3,
            noise             = 0,
            ignore_opacity    = false,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = false,
    },

    cursor = {
        inactive_timeout = 3,
    },

    dwindle = {
        force_split            = 0,
        preserve_split         = true,
        smart_split            = false,
        special_scale_factor   = 0.9,
        split_width_multiplier = 1.0,
        use_active_for_splits  = true,
        default_split_ratio    = 1.0,
    },

    master = {
        allow_small_split    = false,
        special_scale_factor = 0.9,
        mfact                = 0.55,
        new_status           = "master",
        new_on_top           = false,
        orientation          = "left",
    },

    misc = {
        allow_session_lock_restore = true,
        disable_hyprland_logo      = true,
        mouse_move_enables_dpms    = false,
        key_press_enables_dpms     = true,
        focus_on_activate          = true,
        initial_workspace_tracking = false,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        numlock_by_default          = true,
        kb_layout                   = "us",
        repeat_rate                 = 60,
        repeat_delay                = 200,
        follow_mouse                = 1,
        mouse_refocus               = true,
        float_switch_override_focus = 1,
        kb_options                  = "caps:escape",
        accel_profile               = "flat",

        touchpad = {
            disable_while_typing = true,
            natural_scroll       = true,
            scroll_factor        = 1.0,
            tap_to_click         = true,
        },
    },
})


------------------
---- ANIMATIONS --
------------------

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 2, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "default",  style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "borderangle",enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "default" })


-----------------
---- GESTURES ---
-----------------

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

hl.config({
    gestures = {
        workspace_swipe_distance = 100,
    },
})


----------------
---- DEVICES ---
----------------

hl.device({
    name          = "elan1203:00-04f3:307a-touchpad",
    accel_profile = "adaptive",
})
