-- Leader must be set before lazy loads any plugin, otherwise plugin keymaps
-- register against the old leader.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Yanks go to the system clipboard (pbcopy on macOS), so `y` in nvim behaves
-- like copy in the terminal.
vim.opt.clipboard = 'unnamedplus'

-- Mouse drag enters visual mode instead of terminal selection. Copy on release
-- so the selection lands in the clipboard without an extra `y`. `gv` keeps the
-- selection visible afterwards.
vim.keymap.set('x', '<LeftRelease>', '"+ygv', { desc = 'Copy mouse selection to clipboard' })
