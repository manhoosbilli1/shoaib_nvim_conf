-- LazyGit integration for better git workflow
return {
  'kdheepak/lazygit.nvim',
  cmd = {
    'LazyGit',
    'LazyGitConfig',
    'LazyGitCurrentFile',
    'LazyGitFilter',
    'LazyGitFilterCurrentFile',
  },
  -- optional for floating window border decoration
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  -- setting the keybinding for LazyGit with 'keys' is recommended in
  -- order to load the plugin when the command is run for the first time
  keys = {
    { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'LazyGit: Open' },
    { '<leader>lf', '<cmd>LazyGitCurrentFile<cr>', desc = 'LazyGit: Current file' },
    { '<leader>lc', '<cmd>LazyGitConfig<cr>', desc = 'LazyGit: Config' },
  },
  config = function()
    -- Configure LazyGit to use floating window
    vim.g.lazygit_floating_window_winblend = 0 -- transparency of floating window
    vim.g.lazygit_floating_window_scaling_factor = 0.9 -- scaling factor for floating window
    vim.g.lazygit_floating_window_border_chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' } -- customize lazygit popup window border characters
    vim.g.lazygit_floating_window_use_plenary = 0 -- use plenary.nvim to manage floating window if available
    vim.g.lazygit_use_neovim_remote = 1 -- fallback to 0 if neovim-remote is not installed

    -- Set up autocommand to handle LazyGit terminal settings
    vim.api.nvim_create_autocmd('BufEnter', {
      pattern = '*',
      callback = function()
        if vim.bo.filetype == 'lazygit' then
          vim.cmd 'startinsert'
        end
      end,
    })
  end,
}
