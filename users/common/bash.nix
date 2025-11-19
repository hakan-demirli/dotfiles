{
  bashConfigDir ? ../../.config/bash,
  historyFile ? throw "Set this to your history file",
  ...
}:
{
  programs = {
    bash = {
      enable = true;
      historyFile = historyFile;
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "erasedups"
      ];
      enableCompletion = true;
      bashrcExtra = ''
        PROMPT_COMMAND="history -a; history -n"
      '';
      initExtra = ''
        if [ -f "${bashConfigDir}/main.sh" ]; then
          source "${bashConfigDir}/main.sh"
        fi
      '';
    };
  };
}
