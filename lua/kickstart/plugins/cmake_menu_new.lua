-- Complete CMake integration with ToggleTerm - rebuilt from scratch
return {
  'Civitasv/cmake-tools.nvim',
  dependencies = { 'akinsho/toggleterm.nvim', 'nvim-lua/plenary.nvim' },
  config = function()
    -- Simple, robust cmake-tools setup
    require('cmake-tools').setup {
      cmake_command = 'cmake',
      ctest_command = 'ctest',
      cmake_regenerate_on_save = false, -- Don't auto-regenerate
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
      cmake_build_options = {},
      cmake_build_directory = 'build', -- Simple build directory
      cmake_soft_link_compile_commands = true,
      cmake_compile_commands_from_lsp = false,
      cmake_kits_path = nil,
      cmake_variants_message = {
        short = { show = true },
        long = { show = false },
      },
      cmake_executor = {
        name = 'toggleterm',
        opts = {},
        default_opts = {
          toggleterm = {
            direction = 'horizontal',
            close_on_exit = false,
            auto_scroll = true,
          },
        },
      },
      cmake_runner = {
        name = 'toggleterm',
        opts = {},
        default_opts = {
          toggleterm = {
            direction = 'float',
            close_on_exit = false,
            auto_scroll = true,
          },
        },
      },
      cmake_notifications = {
        runner = { enabled = true },
        executor = { enabled = true },
        spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
      },
    }

    local cmake = require('cmake-tools')
    local Terminal = require('toggleterm.terminal').Terminal

    -- Smart project detection
    local function find_project_root()
      local current_dir = vim.fn.expand('%:p:h')
      local root_patterns = { 'CMakeLists.txt', '.git' }
      
      for _, pattern in ipairs(root_patterns) do
        local found = vim.fn.findfile(pattern, current_dir .. ';')
        if found ~= '' then
          return vim.fn.fnamemodify(found, ':h')
        end
      end
      return vim.fn.getcwd()
    end

    -- Get executable path with smart detection
    local function get_executable_path()
      local project_root = find_project_root()
      local build_dir = project_root .. '/build'
      
      -- Try to find any executable in build directory
      local handle = vim.loop.fs_scandir(build_dir)
      if handle then
        while true do
          local name, type = vim.loop.fs_scandir_next(handle)
          if not name then break end
          
          if type == 'file' then
            local file_path = build_dir .. '/' .. name
            -- Check if file is executable (simple check for macOS/Linux)
            local stat = vim.loop.fs_stat(file_path)
            if stat and stat.mode then
              -- Skip files with common non-executable extensions
              if not name:match('%.%w+$') or name:match('%.exe$') then
                return file_path
              end
            end
          end
        end
      end
      
      -- Fallback: try common executable names
      local common_names = { 'myapp', 'main', 'app', 'program' }
      for _, name in ipairs(common_names) do
        local exe_path = build_dir .. '/' .. name
        if vim.fn.filereadable(exe_path) == 1 then
          return exe_path
        end
      end
      
      return nil
    end

    -- Run executable in floating terminal
    local function run_executable()
      local exe_path = get_executable_path()
      if not exe_path then
        vim.notify('No executable found in build directory.\nTry building first!', vim.log.levels.WARN)
        return
      end
      
      local run_term = Terminal:new {
        cmd = exe_path,
        direction = 'float',
        close_on_exit = false,
        float_opts = {
          border = 'curved',
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.8),
        },
      }
      run_term:toggle()
      vim.notify('Running: ' .. vim.fn.fnamemodify(exe_path, ':t'), vim.log.levels.INFO)
    end

    -- Build project with better error handling
    local function build_project(callback)
      local project_root = find_project_root()
      vim.cmd('cd ' .. project_root)
      
      -- Save all files first
      vim.cmd('wall')
      
      vim.notify('Building project...', vim.log.levels.INFO)
      cmake.build({}, function(code, signal, stderr)
        if code == 0 then
          vim.notify('Build successful!', vim.log.levels.INFO)
          if callback then callback() end
        else
          vim.notify('Build failed. Check the terminal for errors.', vim.log.levels.ERROR)
        end
      end)
    end

    -- Generate build files
    local function generate_project()
      local project_root = find_project_root()
      vim.cmd('cd ' .. project_root)
      
      -- Create build directory if it doesn't exist
      vim.fn.mkdir(project_root .. '/build', 'p')
      
      vim.notify('Generating build files...', vim.log.levels.INFO)
      cmake.generate({}, function(code, signal, stderr)
        if code == 0 then
          vim.notify('Generate successful!', vim.log.levels.INFO)
        else
          vim.notify('Generate failed. Check CMakeLists.txt syntax.', vim.log.levels.ERROR)
        end
      end)
    end

    -- Clean build
    local function clean_project()
      vim.notify('Cleaning build...', vim.log.levels.INFO)
      cmake.clean()
    end

    -- Quick setup for new projects
    local function quick_setup()
      local project_root = find_project_root()
      vim.cmd('cd ' .. project_root)
      
      if vim.fn.filereadable(project_root .. '/CMakeLists.txt') == 0 then
        vim.notify('No CMakeLists.txt found in project root!', vim.log.levels.ERROR)
        return
      end
      
      vim.notify('Setting up project...', vim.log.levels.INFO)
      generate_project()
      vim.defer_fn(function()
        build_project()
      end, 1000)
    end

    -- Main menu with better UX
    vim.keymap.set('n', '<leader>m', function()
      local actions = {
        { label = '🚀 Quick Setup (Generate + Build)', action = quick_setup },
        { label = '🔨 Build', action = function() build_project() end },
        { label = '▶️  Run', action = run_executable },
        { label = '🔨▶️  Build & Run', action = function() build_project(run_executable) end },
        { label = '⚙️  Generate', action = generate_project },
        { label = '🧹 Clean', action = clean_project },
        { label = '🎯 Select Target', action = function() vim.cmd('CMakeSelectBuildTarget') end },
        { label = '🔧 Select Kit', action = function() vim.cmd('CMakeSelectKit') end },
        { label = '📝 Select Build Type', action = function() vim.cmd('CMakeSelectBuildType') end },
      }
      
      vim.ui.select(actions, {
        prompt = '🛠️  CMake Actions:',
        format_item = function(item) return item.label end,
      }, function(choice)
        if choice and choice.action then
          choice.action()
        end
      end)
    end, { desc = 'CMake: Open menu' })

    -- Additional helpful keymaps
    vim.keymap.set('n', '<leader>mb', function() build_project() end, { desc = 'CMake: Build' })
    vim.keymap.set('n', '<leader>mr', run_executable, { desc = 'CMake: Run' })
    vim.keymap.set('n', '<leader>mg', generate_project, { desc = 'CMake: Generate' })
    vim.keymap.set('n', '<leader>mc', clean_project, { desc = 'CMake: Clean' })
    vim.keymap.set('n', '<leader>ms', quick_setup, { desc = 'CMake: Quick Setup' })
  end,
}
