{
  plugins.telescope = {
    enable = true;
    keymaps = {
      "<leader>j" = "jumplist";
      "<leader>s" = "lsp_document_symbols";
      "<leader>S" = "lsp_workspace_symbols";
      "<leader>d" = "diagnostics";
      "<leader>a" = "quickfix"; # code actions ?

      "<leader>f" = "find_files";
      "<leader>b" = "buffers";
      "<leader>t" = "help_tags";
      "<leader>?" = "commands";
      "<leader>/" = "live_grep";
      # "<leader>fr" = "oldfiles";
    };
    extensions.fzf-native = {
      enable = true;
    };
  };
}
