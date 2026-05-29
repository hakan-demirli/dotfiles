-- Host-specific config for l02 (HP OmniBook Ultra convertible).
-- Replaces hosts/l02.conf + hosts/l02-rotation.conf.
--
-- orientation_watcher no longer generates a .conf file; it applies
-- rotation via hyprctl keyword at runtime.  The defaults below are
-- used at startup (transform 0 = landscape).

hl.config({
    input = {
        touchdevice = {
            output    = "eDP-1",
            transform = 0,
        },
        tablet = {
            output    = "eDP-1",
            transform = 0,
        },
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("wvkbd-mobintl --hidden -L 280 -l full,special,emoji")
    hl.exec_cmd("sh -c 'mkdir -p ~/.local/state && exec tablet_mode_watcher >>~/.local/state/tablet_mode_watcher.log 2>&1'")
    hl.exec_cmd("sh -c 'mkdir -p ~/.local/state && exec orientation_watcher >>~/.local/state/orientation_watcher.log 2>&1'")
end)

hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("pkill -USR1 -f tablet_mode_watcher"))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("tablet_mode_apply osk-toggle"))
