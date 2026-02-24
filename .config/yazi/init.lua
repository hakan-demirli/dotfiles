require("session"):setup({
  sync_yanked = true,
})

require("git"):setup {
  order = 1500,
}
