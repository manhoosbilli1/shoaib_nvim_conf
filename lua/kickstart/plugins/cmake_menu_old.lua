return {
  'Civitasv/cmake-tools.nvim',
  dependencies = { 'akinsho/toggleterm.nvim', 'nvim-lua/plenary.nvim' },
  config = function()
    -- Setup cmake-tools first
    require('cmake-tools').setup {
      cmake_command = 'cmake',
      ctest_command = 'ctest',
      cmake_regenerate_on_save = true,
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
      cmake_build_options = {},
      cmake_build_directory = 'out/${variant:buildType}',
      cmake_soft_link_compile_commands = true,
      cmake_compile_commands_from_lsp = false,
      cmake_kits_path = nil,
      cmake_variants_message = {
        short = { show = true },
        long = { show = true, max_length = 40 },
      },
      cmake_dap_configuration = {
        name = 'cpp',
        type = 'codelldb',
        request = 'launch',
        stopOnEntry = false,
        runInTerminal = true,
        console = 'integratedTerminal',
      },
      cmake_executor = {
        name = 'quickfix',
        opts = {},
        default_opts = {
          quickfix = {
            show = 'always',
            position = 'belowright',
            size = 10,
            encoding = 'utf-8',
            auto_close_when_success = true,
          },
        },
      },
      cmake_runner = {
        name = 'terminal',
        opts = {},
        default_opts = {
          terminal = {
            name = 'Main Terminal',
            prefix_name = '[CMakeTools]: ',
            split_direction = 'horizontal',
            split_size = 11,
            single_terminal_per_instance = true,
            single_terminal_per_tab = true,
            keep_terminal_static_location = true,
            start_insert = false,
            focus = false,
            do_not_add_newline = false,
          },
        },
      },
      cmake_notifications = {
        runner = { enabled = true },
        executor = { enabled = true },
        spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
      },
    }

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
      
      -- Check if executable exists
      if vim.fn.filereadable(exe_path) == 0 then
        vim.notify('Executable not found: ' .. exe_path .. '\nTry building first.', vim.log.levels.WARN)
        return nil
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
