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


c.auto_save.session = True
c.session.lazy_restore = True
c.tabs.position = "left"
c.tabs.width = 141  # px
c.tabs.wrap = False
c.scrolling.smooth = True
c.content.pdfjs = True
c.content.autoplay = False

# Dark mode
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.threshold.text = 150
c.colors.webpage.darkmode.threshold.background = 100
# c.colors.webpage.darkmode.policy.images = "always"
# c.colors.webpage.darkmode.grayscale.images = 0.35

selected_tab_color = "#260f2e"
c.colors.tabs.even.bg = "black"
c.colors.tabs.odd.bg = "black"
c.colors.tabs.pinned.even.bg = "#080d2b"
c.colors.tabs.pinned.odd.bg = "#080d2b"
c.colors.tabs.selected.odd.bg = selected_tab_color
c.colors.tabs.selected.even.bg = selected_tab_color
c.colors.tabs.pinned.selected.odd.bg = selected_tab_color
c.colors.tabs.pinned.selected.even.bg = selected_tab_color
# c.colors.tabs.pinned.even.fg = "black"
# c.colors.tabs.pinned.odd.fg = "black"

c.input.insert_mode.auto_load = True
# c.spellcheck.languages = ["en-GB"]
c.tabs.background = True
c.url.open_base_url = True
c.url.start_pages = """https://duckduckgo.com//?q={}"""
c.url.default_page = "about:blank"
c.url.searchengines = {
    "DEFAULT": """https://duckduckgo.com/?q={}""",
    "ddg": """https://duckduckgo.com//?q={}""",
}
c.tabs.title.format_pinned = "{audio}{index}: {current_title}"
c.window.title_format = "{perc}{current_title}{title_sep}nephestate browser"
c.editor.command = ["st", "-e", "helix", "{file}", "-c", "normal {line}G{column0}l"]

# Custom aliases
c.aliases.update(
    {
        "bc": "tab-close",
        "pin": "tab-pin",
        "tabselect": "tab-select",
    }
)


config.bind("j", "jseval --quiet scrollHelper.scrollBy(100)")
config.bind("k", "jseval --quiet scrollHelper.scrollBy(-100)")
config.bind("<Ctrl-D>", "jseval --quiet scrollHelper.scrollPage(0.5)")
config.bind("<Ctrl-U>", "jseval --quiet scrollHelper.scrollPage(-0.5)")
config.bind("gg", "jseval --quiet scrollHelper.scrollTo(0)")
config.bind("ge", "jseval --quiet scrollHelper.scrollToPercent(100)")
config.bind("gp", "tab-prev")
config.bind("gn", "tab-next")


config.bind("q", "nop")

# password management
# BUG: ... may not contain unprintable characters. Can't use regex.
# """--username-target "secret" --username-pattern "(?:^[^\n]*\n?){1}(.*)" --password-pattern "(.+)" """
# Just edit the qute-ass script instead of using regex.
config.bind(
    "pl",
    'spawn --userscript qute-pass --username-target secret --username-pattern "username: (.+)"',
    # """spawn --userscript qute-pass  --username-target "secret" """,
)
config.bind(
    "pu",
    """spawn --userscript qute-pass  --username-target "secret" --username-only""",
)
config.bind(
    "pp",
    """spawn --userscript qute-pass  --username-target "secret" --password-only""",
)
config.bind(
    "po",
    """spawn --userscript qute-pass  --username-target "secret" --otp-only""",
)


config.bind("<space>p", "tab-pin")
config.bind("<space>f", "set-cmd-text -s :tab-select")
config.bind("<Alt-q>", "tab-select 1")
config.bind("<Alt-w>", "tab-select 2")
config.bind("<Alt-e>", "tab-select 3")
config.bind("<Alt-r>", "tab-select 4")
config.bind("o", "set-cmd-text -s :open -t ")


# Video Speed Controls
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


# adblock
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
