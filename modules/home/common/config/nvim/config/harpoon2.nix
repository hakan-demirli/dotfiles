{ pkgs, ... }:
{
  extraPlugins = with pkgs.vimPlugins; [ harpoon2 ];
  extraConfigLua = ''
    local harpoon = require("harpoon")
    harpoon:setup(
      {
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
          key = function()
              return vim.loop.cwd()
          end,
        },
      }
    )

    vim.keymap.set("n", "<A-g>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
    vim.keymap.set("n", "<A-a>", function() harpoon:list():add() end)

    vim.keymap.set("n", "<A-u>", function() harpoon:list():select(1) end)
    vim.keymap.set("n", "<A-i>", function() harpoon:list():select(2) end)
    vim.keymap.set("n", "<A-o>", function() harpoon:list():select(3) end)
    vim.keymap.set("n", "<A-p>", function() harpoon:list():select(4) end)
    vim.keymap.set("n", "<C-S-k>", function() harpoon:list():prev() end)
    vim.keymap.set("n", "<C-S-j>", function() harpoon:list():next() end)
  '';
}
