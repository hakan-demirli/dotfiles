import os
from urllib.request import urlopen

config.load_autoconfig(False)


if not os.path.exists(config.configdir / "theme.py"):
    theme = "https://raw.githubusercontent.com/catppuccin/qutebrowser/main/setup.py"
    with urlopen(theme) as themehtml:
        with open(config.configdir / "theme.py", "a") as file:
            file.writelines(themehtml.read().decode("utf-8"))

if os.path.exists(config.configdir / "theme.py"):
    import theme

    theme.setup(c, "mocha", True)


# bindings.commands = {"normal": {";w": "hint links spawn --detach mpv --force-window yes {hint-url}", "pt": "pin-tab"}}
config.bind("pt", "tab-pin")
config.bind(";w", "hint links spawn --detach mpv --force-window yes {hint-url}")
config.bind(";W", "spawn --detach mpv --force-window yes {url}")
config.bind(
    ";I",
    'hint images spawn --output-messages wget -P "/home/emre/Downloads/Qute/" {hint-url}',
)
config.bind("q", "nop")

# password management
config.bind("ee", "spawn --userscript qute-pass")
config.bind("eu", "spawn --userscript qute-pass --username-only")
config.bind("ep", "spawn --userscript qute-pass --password-only")
config.bind("eo", "spawn --userscript qute-pass --otp-only")

c.colors.tabs.even.bg = "grey"
c.colors.tabs.odd.bg = "darkgrey"

c.content.blocking.method = "adblock"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist.to/easylist/fanboy-social.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt",
    # "https://gitlab.com/curben/urlhaus-filter/-/raw/master/urlhaus-filter.txt",
    "https://pgl.yoyo.org/adservers/serverlist.php?showintro=0;hostformat=hosts",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/legacy.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2020.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2021.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2022.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/filters-2023.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/badware.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/privacy.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/badlists.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/annoyances.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/resource-abuse.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/unbreak.txt",
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=1",
    "https://www.i-dont-care-about-cookies.eu/abp/",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    "https://github.com/uBlockOrigin/uAssets/raw/master/filters/unbreak.txt",
]

c.content.pdfjs = True
c.content.autoplay = False

c.editor.command = ["st", "-e", "vim", "{file}", "-c", "normal {line}G{column0}l"]

c.input.insert_mode.auto_load = True
# c.spellcheck.languages = ["en-GB"]

c.tabs.background = True
c.tabs.title.format_pinned = "{index} {audio}"

c.url.open_base_url = True
c.url.start_pages = """https://duckduckgo.com/?k7=282a36&amp;k8=f8f8f2&amp;k9=50fa7b&amp;kae=t&amp;kt=p&amp;ks=m&amp;kw=n&amp;km=l&amp;ko=s&amp;kj=282a36&amp;ka=p&amp;kaa=bd93f9&amp;ku=-1&amp;kx=f1fa8c&amp;ky=44475a&amp;kaf=1&amp;kai=1&amp;kf=1/?q={}"""
c.url.default_page = "about:blank"

c.url.searchengines = {
    "DEFAULT": """https://duckduckgo.com/?k7=282a36&amp;k8=f8f8f2&amp;k9=50fa7b&amp;kae=t&amp;kt=p&amp;ks=m&amp;kw=n&amp;km=l&amp;ko=s&amp;kj=282a36&amp;ka=p&amp;kaa=bd93f9&amp;ku=-1&amp;kx=f1fa8c&amp;ky=44475a&amp;kaf=1&amp;kai=1&amp;kf=1/?q={}""",
    "ddg": """https://duckduckgo.com/?k7=282a36&amp;k8=f8f8f2&amp;k9=50fa7b&amp;kae=t&amp;kt=p&amp;ks=m&amp;kw=n&amp;km=l&amp;ko=s&amp;kj=282a36&amp;ka=p&amp;kaa=bd93f9&amp;ku=-1&amp;kx=f1fa8c&amp;ky=44475a&amp;kaf=1&amp;kai=1&amp;kf=1/?q={}""",
    "ksl": "https://classifieds.ksl.com/search?keyword={}",
    "tw": "https://twitch.tv/{}",
    "dlive": "https://dlive.tv/{}",
    "ig": "https://infogalactic.com/w/index.php?search={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

c.window.title_format = "{perc}{current_title}{title_sep}nephestate browser"


# Configure the filepicker
filepicker = [
    "kitty",
    "--class",
    "filepicker",
    "--title",
    "filepicker",
    "-e",
    "lf",
    "-command",
    "set nohidden",
    "-selection-path={}",
]
c.fileselect.handler = "external"
c.fileselect.folder.command = filepicker
c.fileselect.multiple_files.command = filepicker
c.fileselect.single_file.command = filepicker


config.bind("j", "jseval --quiet scrollHelper.scrollBy(100)")
config.bind("k", "jseval --quiet scrollHelper.scrollBy(-100)")
config.bind("<Ctrl-D>", "jseval --quiet scrollHelper.scrollPage(0.5)")
config.bind("<Ctrl-U>", "jseval --quiet scrollHelper.scrollPage(-0.5)")
config.bind("gg", "jseval --quiet scrollHelper.scrollTo(0)")
config.bind("G", "jseval --quiet scrollHelper.scrollToPercent(100)")


config.bind(
    "s",
    'jseval --quiet document.querySelector("video, audio").playbackRate = parseFloat(document.querySelector("video, audio").playbackRate - 0.1).toFixed(1)',
)
config.bind(
    "d",
    'jseval --quiet document.querySelector("video, audio").playbackRate = parseFloat(document.querySelector("video, audio").playbackRate + 0.1).toFixed(1)',
)
config.bind(
    "r",
    'jseval --quiet document.querySelector("video, audio").playbackRate = 1',
)
config.bind(
    "R",
    "reload",
)


# Dark mode
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.threshold.text = 150
c.colors.webpage.darkmode.threshold.background = 100
# c.colors.webpage.darkmode.policy.images = "always"
# c.colors.webpage.darkmode.grayscale.images = 0.35
