_: {

  home.shellAliases = {
    ":q" = "exit";
    "q:" = "exit";
    ":wq" = "exit";
    "hx." = "helix .";
    ".." = "cd ..";
    "c" = "clear";
    "cd.." = "cd ..";
    helix = "hx";
    lf = ''echo "Did you mean f?"''; # muscle memory
    # f = "lf_cd";
    f = "yazi_cd";
    ff = "yazi_cd";
    cdf = ''cd "$(find . -type d | fzf)"'';
    da = "direnv allow";
    # tt = ''tt --window_state=list'';
    # tl = ''task list'';
    ch = "cheat_sheet.sh";

    git = "git_cached";
    "ga." = "git add .";
    ga = "git add";
    gd = "git -c diff.external=difft diff";
    gdc = "git -c diff.external=difft diff --cached";
    gp = "git push";
    gpf = "git push --force";
    gr = "git restore";
    "gr." = "git restore .";
    grs = "git restore --staged";
    gs = "git status";
    gb = "fzf_git_branches";
    gc = "git commit";
    gcm = "git commit -m ";
    gca = "git commit --amend";
    gl = "fzf_git_commits";

    bell = "source $HOME/.local/bin/prompt-bell";
    tbell = "source $HOME/.local/bin/prompt-tnotify.sh";
    tbell-fg = "source $HOME/.local/bin/prompt-tnotify-fg.sh";

    # ascp = "asusctl profile -p";
    # ascl = "asusctl profile -l";
    # ascsp = "asusctl profile -P Performance";
    # ascsb = "asusctl profile -P Balanced";
    # ascsq = "asusctl profile -P Quiet";
    yarn = ''yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/config"'';

    tmux = "tmux -f ~/.config/tmux/tmux.conf";
    txa = ''tmux attach-session -t $(tmux list-sessions -F "#{session_name}" | head -n 1)'';
    txls = "tmux list-sessions";
    txks = "tmux kill-session -t ";
    txn = "tmux new-session -s";
    txs = "tmux switch-client -n";
    txkw = "tmux kill-window -t ";
    txlw = "tmux list-windows";
    # txh = ''tmux new-session -s "$(basename "$(pwd)")_$(echo -n "$(pwd)" | md5sum | cut -d " " -f 1)" "hx ."'';

    wget = ''wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'';
    arduino-cli = "arduino-cli --config-file $XDG_CONFIG_HOME/arduino15/arduino-cli.yaml";

    # llama = ''nix run git+https://github.com/nixified-ai/flake.git#textgen-nvidia'';

    fan-turbo = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 1 >>  fan_boost_mode"; sudo sh -c "echo 1 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
    fan-performance = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 0 >>  fan_boost_mode"; sudo sh -c "echo 0 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
    fan-silent = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 2 >>  fan_boost_mode"; sudo sh -c "echo 2 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
  };
}
