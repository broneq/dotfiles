return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    -- Parsers markdown, markdown_inline and html ship with Neovim 0.12,
    -- so nvim-treesitter is not required here.
    opts = {
      completions = { lsp = { enabled = true } },
    },
  },
  {
    -- Browser preview driven from Neovim: mermaid, KaTeX, scroll sync.
    -- Pure Lua, no npm and no build step, so a fresh machine needs nothing extra.
    'selimacerbas/markdown-preview.nvim',
    dependencies = { 'selimacerbas/live-server.nvim' },
    ft = { 'markdown' },
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewRefresh' },
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreview<cr>',        ft = 'markdown', desc = 'Markdown Preview' },
      { '<leader>mP', '<cmd>MarkdownPreviewStop<cr>',    ft = 'markdown', desc = 'Markdown Preview Stop' },
      { '<leader>mr', '<cmd>MarkdownPreviewRefresh<cr>', ft = 'markdown', desc = 'Markdown Preview Refresh' },
    },
    config = function()
      require('markdown_preview').setup({
        default_theme = 'dark',
      })
    end,
  },
}
