return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      picker = { enabled = true },    -- fuzzy finder: files, grep, buffers
      notifier = { enabled = true },  -- pretty vim.notify
      input = { enabled = true },     -- better vim.ui.input
    },
    keys = {
      { '<leader>f', function() Snacks.picker.files() end,   desc = 'Find Files' },
      { '<leader>s', function() Snacks.picker.grep() end,    desc = 'Search Text' },
      { '<leader>b', function() Snacks.picker.buffers() end, desc = 'Buffers' },
      -- Deliberately omitted: Snacks.picker.lsp_definitions() on `gd`.
      -- No LSP server is configured yet, so the mapping would silently do nothing.
      -- Add it together with nvim-lspconfig, not before.
    },
  },
}
