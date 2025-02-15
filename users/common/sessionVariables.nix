{ config, pkgs, ... }:
rec {
  home.sessionVariables = {
    OPENER = "xdg-open";
    EDITOR = "hx";
    TERMINAL = "kitty";
    TERM = "kitty";

    GTK_THEME = "Dracula"; # config.gtk.theme.name;

    # export PATH="${config.home.sessionVariables.XDG_DATA_HOME}:${XDG_CONFIG_HOME}:$XDG_STATE_HOME:$XDG_CACHE_HOME:$PATH"
    # env = PATH,$HOME/.local/bin:$PATH
    # env = PATH,/usr/local/bin:$PATH

    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_STATE_HOME = "$HOME/.local/state";
    XDG_CACHE_HOME = "$HOME/.cache";

    DIRENV_WARN_TIMEOUT = "8m";

    # WARNING: DO NOT SET DIRENV_CONFIG
    # DIRENV_CONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/direnv/direnvrc";
    WINEPREFIX = "${home.sessionVariables.XDG_DATA_HOME}/wine"; # special case
    ANDROID_HOME = "${home.sessionVariables.XDG_DATA_HOME}/android";
    CARGO_HOME = "${home.sessionVariables.XDG_DATA_HOME}/cargo";
    CUDA_CACHE_PATH = "${home.sessionVariables.XDG_CACHE_HOME}/nv";
    GNUPGHOME = "${home.sessionVariables.XDG_DATA_HOME}/gnupg"; # handled in home manager
    PASSWORD_STORE_DIR = "${home.sessionVariables.XDG_DATA_HOME}/password-store";
    RUSTUP_HOME = "${home.sessionVariables.XDG_DATA_HOME}/rustup";
    NUGET_PACKAGES = "${home.sessionVariables.XDG_CACHE_HOME}/NuGetPackages";
    NPM_CONFIG_USERCONFIG = "${home.sessionVariables.XDG_CONFIG_HOME}/npm/npmrc";
    DOTNET_CLI_HOME = "/tmp/DOTNET_CLI_HOME";
    WGETRC = "${home.sessionVariables.XDG_CONFIG_HOME}/wgetrc";
    KIVY_HOME = "${home.sessionVariables.XDG_CONFIG_HOME}/kivy";
    PYTHONPYCACHEPREFIX = "${home.sessionVariables.XDG_CACHE_HOME}/python";
    PYTHONUSERBASE = "${home.sessionVariables.XDG_DATA_HOME}/python";
    PYTHON_HISTORY = "${home.sessionVariables.XDG_STATE_HOME}/python/history";
    PYTHONSTARTUP = "${home.sessionVariables.XDG_STATE_HOME}/python/pythonrc";
    GOPATH = "${home.sessionVariables.XDG_CACHE_HOME}/go";
    PARALLEL_HOME = "${home.sessionVariables.XDG_CONFIG_HOME}/parallel";
    MYSQL_HISTFILE = "${home.sessionVariables.XDG_DATA_HOME}/mysql_history";
    SQLITE_HISTORY = "${home.sessionVariables.XDG_CACHE_HOME}/sqlite_history";
    DUCKDB_HISTORY = "${home.sessionVariables.XDG_CACHE_HOME}/duckdb_history";
    GRIPHOME = "${home.sessionVariables.XDG_CONFIG_HOME}/grip";
    GDBHISTFILE = "${home.sessionVariables.XDG_STATE_HOME}/gdb/history";
    # _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=$${XDG_CONFIG_HOME}}/java"; # not working
    KERAS_HOME = "${home.sessionVariables.XDG_STATE_HOME}/keras";
    # GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc"; # handled in home manager
    GTK_RC_FILES = "${home.sessionVariables.XDG_CONFIG_HOME}/gtk-1.0/gtkrc";
    # Breaks neovim
    # VIMINIT = ''set nocp | source ''$${XDG_CONFIG_HOME}:-$HOME/.config}/vim/vimrc'';
    TEXMFHOME = "${home.sessionVariables.XDG_DATA_HOME}/texmf";
    TEXMFVAR = "${home.sessionVariables.XDG_CACHE_HOME}/texlive/texmf-var";
    TEXMFCONFIG = "${home.sessionVariables.XDG_CONFIG_HOME}/texlive/texmf-config";

    OLLAMA_MODELS = "${home.sessionVariables.XDG_DATA_HOME}/ollama/models";
    LEIN_HOME = "${home.sessionVariables.XDG_DATA_HOME}/lein";

    LM_LICENSE_FILE = "${home.sessionVariables.XDG_CONFIG_HOME}/mylib/questa_license.dat";

    PDK_ROOT = "${home.sessionVariables.XDG_DATA_HOME}/pdk";

    IGNOREEOF = "4";
    # needed by termfilechooser portal, # not working
    # TERMCMD = "${pkgs.kitty}/bin/kitty --class=file_chooser --override background_opacity=1";
  };
}
