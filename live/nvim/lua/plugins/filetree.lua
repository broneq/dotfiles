return {
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },  -- file icons, needs a Nerd Font
    cmd = { 'NvimTreeToggle', 'NvimTreeOpen', 'NvimTreeFindFile', 'NvimTreeFocus' },
    keys = {
      { '<leader>e', '<cmd>NvimTreeToggle<cr>',   desc = 'File Tree' },
      { '<leader>E', '<cmd>NvimTreeFindFile<cr>', desc = 'File Tree (reveal current file)' },
    },
    init = function()
      -- netrw conflicts with nvim-tree on directory buffers; disable it before
      -- Neovim has a chance to load it.
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    opts = {
      view = { width = 35 },
      renderer = { group_empty = true },  -- collapse a/b/c chains of empty dirs
      filters = { dotfiles = false },     -- show dotfiles, `H` toggles them
      git = { ignore = false },           -- show gitignored files, `I` toggles them
    },
  },
}
