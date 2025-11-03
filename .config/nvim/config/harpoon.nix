{
  plugins.harpoon.enable = true; # The name, is the harpoon-maker-agen
  extraConfigLua = /* lua */ ''
    -- Primeagen Harpoon config
    local mark = require("harpoon.mark")
    local ui = require("harpoon.ui")

    vim.keymap.set("n", "<A-y>", mark.add_file)
    vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)
    vim.keymap.set("n", "<A-u>", function() ui.nav_file(1) end)
    vim.keymap.set("n", "<A-i>", function() ui.nav_file(2) end)
    vim.keymap.set("n", "<A-o>", function() ui.nav_file(3) end)
    vim.keymap.set("n", "<A-p>", function() ui.nav_file(4) end)
  '';
}
