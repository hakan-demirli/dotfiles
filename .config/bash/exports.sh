#!/usr/bin/env bash

# Core tools
export OPENER="xdg-open"
export EDITOR="hx"
export TERMINAL="kitty"
export TERM="kitty"

# Man pages
export MANPAGER="less -R --use-color -Dd+r -Du+b"
export MANROFFOPT="-P -c"

# Theming
export GTK_THEME="Dracula"

# XDG Base Directory Specification
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Application-specific variables following XDG specs
export DIRENV_WARN_TIMEOUT="8m"
export WINEPREFIX="${XDG_DATA_HOME}/wine"
export ANDROID_HOME="${XDG_DATA_HOME}/android"
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export CUDA_CACHE_PATH="${XDG_CACHE_HOME}/nv"
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME}/password-store"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"
export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
export DOTNET_CLI_HOME="/tmp/DOTNET_CLI_HOME"
export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
export KIVY_HOME="${XDG_CONFIG_HOME}/kivy"
export PYTHONPYCACHEPREFIX="${XDG_CACHE_HOME}/python"
export PYTHONUSERBASE="${XDG_DATA_HOME}/python"
export PYTHON_HISTORY="${XDG_STATE_HOME}/python/history"
export PYTHONSTARTUP="${XDG_STATE_HOME}/python/pythonrc"
export GOPATH="${XDG_CACHE_HOME}/go"
export PARALLEL_HOME="${XDG_CONFIG_HOME}/parallel"
export MYSQL_HISTFILE="${XDG_DATA_HOME}/mysql_history"
export SQLITE_HISTORY="${XDG_CACHE_HOME}/sqlite_history"
export DUCKDB_HISTORY="${XDG_CACHE_HOME}/duckdb_history"
export GRIPHOME="${XDG_CONFIG_HOME}/grip"
export GDBHISTFILE="${XDG_STATE_HOME}/gdb/history"
export MUTAGEN_DATA_DIRECTORY="${XDG_STATE_HOME}/mutagen"
export KERAS_HOME="${XDG_STATE_HOME}/keras"
export GTK_RC_FILES="${XDG_CONFIG_HOME}/gtk-1.0/gtkrc"
export TEXMFHOME="${XDG_DATA_HOME}/texmf"
export TEXMFVAR="${XDG_CACHE_HOME}/texlive/texmf-var"
export TEXMFCONFIG="${XDG_CONFIG_HOME}/texlive/texmf-config"
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"
export LEIN_HOME="${XDG_DATA_HOME}/lein"
export LM_LICENSE_FILE="${XDG_CONFIG_HOME}/mylib/questa_license.dat"
export PDK_ROOT="${XDG_DATA_HOME}/pdk"
export IPYTHONDIR="${XDG_DATA_HOME}/ipython"
export JUPYTER_CONFIG_DIR="${XDG_CONFIG_HOME}/jupyter"

# Shell behavior
export IGNOREEOF="4"
