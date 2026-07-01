mainMod = "SUPER"

require("monitors")
require("workspaces")

require("includes")

if os.getenv("HYPRLAND_IS_L01") then require("hosts.l01") end
if os.getenv("HYPRLAND_IS_L02") then require("hosts.l02") end


hl.layer_rule({ name = "blur-waybar",        match = { namespace = "waybar" },     blur = true })
hl.layer_rule({ name = "blur-tofi",          match = { namespace = "tofi" },       blur = true })
hl.layer_rule({ name = "no-anim-hyprpicker", match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ name = "no-anim-selection",  match = { namespace = "selection" },  no_anim = true })
hl.layer_rule({ name = "no-anim-all",        match = { class = ".*" },             no_anim = true })


hl.window_rule({ name = "float-dialog", match = { class = "dialog", title = "Choose symbol" }, float = true })
hl.window_rule({ name = "float-zenity", match = { class = "zenity" }, float = true })

hl.window_rule({ name = "ws1-firefox",     match = { class = "firefox" },     workspace = 1 })
hl.window_rule({ name = "ws1-qutebrowser", match = { class = "qutebrowser" }, workspace = 1 })
hl.window_rule({ name = "ws2-kitty",       match = { class = "kitty" },       workspace = 2 })
hl.window_rule({ name = "ws3-anki",        match = { class = "Anki" },        workspace = 3 })
hl.window_rule({ name = "ws3-gtkwave",     match = { class = "gtkwave" },     workspace = 3 })
hl.window_rule({ name = "ws3-surfer",      match = { title = "Surfer" },      workspace = 3 })
hl.window_rule({ name = "ws3-vsim",        match = { class = "Vsim" },        workspace = 3 })
hl.window_rule({ name = "ws3-windowobj",   match = { class = "WindowObj" },   workspace = 3 })
hl.window_rule({ name = "ws3-vsim-err",    match = { class = "Dialog", title = "Error in Tcl Script" }, workspace = 3 })
hl.window_rule({ name = "ws3-thunderbird", match = { class = "thunderbird" }, workspace = 3 })
hl.window_rule({ name = "ws4-drawio",      match = { class = "draw.io" },     workspace = 4 })

hl.window_rule({ name = "wine-float",  match = { title = ".*Wine.*" }, center = true, float = true })

hl.window_rule({
    name  = "steam-focus",
    match = { class = "^steam$", title = "^$" },
    stay_focused = true,
    min_size     = "1 1",
})

hl.window_rule({
    name  = "firefox-pip",
    match = { class = "^firefox$", title = "^Picture%-in%-Picture$" },
    float = true,
    pin   = true,
})

hl.window_rule({
    name  = "ripdrag-pin",
    match = { class = "^it.catboy.ripdrag$" },
    move  = "(cursor_x+(-(monitor_w*0.05))) (cursor_y+((monitor_h*0)))",
    pin   = true,
})
hl.window_rule({
    name  = "xdragon-pin",
    match = { class = "^xdragon$" },
    move  = "(cursor_x+(-(monitor_w*0.05))) (cursor_y+((monitor_h*0)))",
    pin   = true,
})

hl.window_rule({
    name  = "showmethekeys",
    match = { class = "^showmethekey%-gtk$" },
    float            = true,
    size             = "220 100",
    move             = "((monitor_w*0)) ((monitor_h*0.9))",
    no_focus         = true,
    no_initial_focus = true,
    pin              = true,
    monitor          = "HDMI-A-1",
    border_size      = 0,
    no_shadow        = true,
})

hl.window_rule({
    name  = "xwayland-videobridge",
    match = { class = "^xwaylandvideobridge$" },
    workspace        = 1,
    opacity          = "0.0 override",
    no_anim          = true,
    no_initial_focus = true,
    max_size         = "1 1",
    no_blur          = true,
    no_focus         = true,
})

hl.window_rule({
    name  = "crosscode-idle",
    match = { class = "^CrossCode$" },
    idle_inhibit = "always",
})

hl.window_rule({ name = "flameshot-noanim", match = { class = "^flameshot$" }, no_anim = true })
hl.window_rule({
    name  = "satty-fullscreen",
    match = { class = "^com.gabm.satty$", title = "^satty$" },
    fullscreen = true,
    float      = true,
})

hl.window_rule({ name = "player-special",    match = { class = "kitty", title = "my_player" }, workspace = "special" })
hl.window_rule({ name = "btop-special",      match = { class = "kitty", title = "my_btop" },   workspace = "special:btop" })
hl.window_rule({ name = "qalculate-special", match = { class = "qalculate%-qt" },              float = true, workspace = "special:calculator" })
hl.window_rule({ name = "qalculate2-special",match = { class = "io.github.Qalculate.qalculate%-qt" }, float = true, workspace = "special:calculator" })
hl.window_rule({ name = "todo-special",      match = { class = "kitty", title = "my_todo" },   workspace = "special:todo" })
hl.window_rule({ name = "plan-special",      match = { class = "kitty", title = "my_plan" },   workspace = "special:plan" })

hl.window_rule({
    name  = "anydesk-float",
    match = { class = "^Anydesk$", title = "^anydesk$" },
    float = true,
})

hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "xwayland-drag-fix",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})


hl.bind("ALT + N",            hl.dsp.exec_cmd("todo_my"))
hl.bind("ALT + Z",            hl.dsp.exec_cmd("plan_my"))
hl.bind(mainMod .. " + M",    hl.dsp.exec_cmd("player_my"))

hl.bind("ALT + Tab",    hl.dsp.focus({ last = true }))
hl.bind("ALT + M",      hl.dsp.focus({ workspace = 1 }))
hl.bind("ALT + COMMA",  hl.dsp.focus({ workspace = 2 }))
hl.bind("ALT + PERIOD", hl.dsp.focus({ workspace = 3 }))
hl.bind("ALT + SLASH",  hl.dsp.focus({ workspace = 4 }))

hl.bind(mainMod .. " + B",   hl.dsp.exec_cmd("pkill waybar || waybar"))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ last = true }))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -20, y = 0 }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0,   y = 20 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0,   y = -20 }),{ repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 20,  y = 0 }),  { repeating = true })

hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + escape",  hl.dsp.exec_cmd(locker))
hl.bind(mainMod .. " + S",      hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + E",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R",      hl.dsp.window.pin())

hl.bind("Print",                      hl.dsp.exec_cmd("pkill -9 wayscriber || wayscriber -a"))
hl.bind(mainMod .. " + SHIFT + S",    hl.dsp.exec_cmd("pkill -9 wayscriber || wayscriber -a"))
hl.bind(mainMod .. " + Y",            hl.dsp.exec_cmd("pkill -9 wayscriber || wayscriber -a"))

hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(launcher), { release = true })
hl.bind("SUPER + SUPER_R", hl.dsp.exec_cmd(launcher), { release = true })

hl.bind(mainMod .. " + CTRL + F4", hl.dsp.exit())

for i = 1, 9 do
    hl.bind(mainMod .. " + CTRL + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume +5"),          { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume -5"),          { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness +10"),            { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness -10"),            { locked = true })

hl.bind("XF86Calculator", hl.dsp.exec_cmd("qalculate_my"), { locked = true })
hl.bind("XF86Launch2",    hl.dsp.exec_cmd(launcher),       { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("XF86ScreenSaver", hl.dsp.dpms({ action = "toggle" }), { locked = true })

hl.bind("XF86Launch8", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),     { locked = true })
hl.bind("XF86Launch7", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86Tools",   hl.dsp.exec_cmd("brightnessctl s 10%+"),                          { locked = true })
hl.bind("XF86Launch5", hl.dsp.exec_cmd("brightnessctl s 10%-"),                          { locked = true })
hl.bind("XF86Launch6", hl.dsp.dpms({ action = "toggle" }),                                { locked = true })

hl.bind("XF86Launch8", hl.dsp.exec_cmd("swayosd-client --output-volume 5"),  { locked = true })
hl.bind("XF86Launch7", hl.dsp.exec_cmd("swayosd-client --output-volume -5"), { locked = true })
hl.bind("XF86Tools",   hl.dsp.exec_cmd("swayosd-client --brightness +10"),   { locked = true })
hl.bind("XF86Launch5", hl.dsp.exec_cmd("swayosd-client --brightness -10"),   { locked = true })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
