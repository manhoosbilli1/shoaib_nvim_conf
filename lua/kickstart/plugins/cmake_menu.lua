return {
  'Civitasv/cmake-tools.nvim',
  dependencies = { 'akinsho/toggleterm.nvim', 'nvim-lua/plenary.nvim' },
  config = function()
    local cmake = require 'cmake-tools'
    local Terminal = require('toggleterm.terminal').Terminal

    -- Helper to get executable path
    local function get_exe_path()
      local build_dir = cmake.get_build_directory() or 'build'
      local target = cmake.get_build_target()
      local target_name = nil
      if type(target) == 'table' then
        target_name = target.name or target[1]
      elseif type(target) == 'string' then
        target_name = target
      end
      if not target_name or target_name == '' then
        vim.notify('No CMake target selected.', vim.log.levels.WARN)
        return nil
      end
      local exe_path = build_dir .. '/' .. target_name
      if vim.loop.os_uname().sysname == 'Windows_NT' then
        exe_path = exe_path .. '.exe'
      end
      return exe_path
    end

    -- Run executable in floating terminal
    local function run_exe()
      local exe_path = get_exe_path()
      if not exe_path then
        return
      end
      local run_term = Terminal:new {
        cmd = exe_path,
        direction = 'float',
        close_on_exit = false,
      }
      run_term:toggle()
    end

    -- Actions menu
    vim.keymap.set('n', '<leader>m', function()
      local actions = {
        {
          label = 'Build & Run',
          action = function()
            cmake.build({}, function()
              run_exe()
            end)
          end,
        },
        {
          label = 'Generate',
          action = function()
            vim.cmd 'CMakeGenerate'
          end,
        },
        {
          label = 'Select Kit',
          action = function()
            vim.cmd 'CMakeSelectKit'
          end,
        },
        {
          label = 'Select Build Type',
          action = function()
            vim.cmd 'CMakeSelectBuildType'
          end,
        },
        {
          label = 'Select Target',
          action = function()
            vim.cmd 'CMakeSelectBuildTarget'
          end,
        },
        {
          label = 'Build',
          action = function()
            cmake.build()
          end,
        },
        {
          label = 'Run',
          action = function()
            run_exe()
          end,
        },
        {
          label = 'Clean',
          action = function()
            vim.cmd 'CMakeClean'
          end,
        },
      }
      vim.ui.select(actions, {
        prompt = 'CMake/ToggleTerm Action:',
        format_item = function(item)
          return item.label
        end,
      }, function(choice)
        if choice and choice.action then
          choice.action()
        end
      end)
    end, { desc = 'CMake/ToggleTerm: Menu' })
  end,
}
