-- Simple CMake menu with direct terminal commands - reliable and fast
return {
  'akinsho/toggleterm.nvim',
  config = function()
    -- Setup toggleterm
    require('toggleterm').setup {
      direction = 'float',
      float_opts = {
        border = 'curved',
        width = math.floor(vim.o.columns * 0.9),
        height = math.floor(vim.o.lines * 0.9),
      },
    }

    local Terminal = require('toggleterm.terminal').Terminal

    -- Track running processes
    local running_processes = {
      terminal = nil,
      background_job = nil,
    }

    -- Smart project detection
    local function find_project_root()
      local current_dir = vim.fn.expand('%:p:h')
      if current_dir == '' then
        current_dir = vim.fn.getcwd()
      end
      
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
      
      -- Check if build directory exists
      if vim.fn.isdirectory(build_dir) == 0 then
        return nil
      end
      
      -- Try to find any executable in build directory
      local files = vim.fn.readdir(build_dir)
      for _, name in ipairs(files) do
        local file_path = build_dir .. '/' .. name
        -- Check if file is executable and not a common non-executable file
        if vim.fn.executable(file_path) == 1 and not name:match('%.%w+$') then
          return file_path
        end
      end
      
      -- Fallback: try common executable names
      local common_names = { 'myapp', 'main', 'app', 'program' }
      for _, name in ipairs(common_names) do
        local exe_path = build_dir .. '/' .. name
        if vim.fn.filereadable(exe_path) == 1 and vim.fn.executable(exe_path) == 1 then
          return exe_path
        end
      end
      
      return nil
    end

    -- Stop running processes
    local function stop_running_processes()
      -- Close terminal if running
      if running_processes.terminal and running_processes.terminal:is_open() then
        running_processes.terminal:close()
        vim.notify('🛑 Stopped terminal process', vim.log.levels.INFO)
      end
      
      -- Stop background job if running
      if running_processes.background_job then
        if vim.fn.jobstop then
          vim.fn.jobstop(running_processes.background_job)
        elseif vim.system then
          -- For newer Neovim versions, we'll track differently
          -- Background processes will be harder to track, but we'll do our best
        end
        running_processes.background_job = nil
        vim.notify('🛑 Stopped background process', vim.log.levels.INFO)
      end
    end

    -- Run executable in terminal (top right)
    local function run_executable()
      local exe_path = get_executable_path()
      if not exe_path then
        vim.notify('❌ No executable found in build directory.\nTry building first!', vim.log.levels.WARN)
        return
      end
      
      -- Stop any existing processes first
      stop_running_processes()
      
      local project_root = find_project_root()
      local exe_name = vim.fn.fnamemodify(exe_path, ':t')
      
      local run_term = Terminal:new {
        cmd = 'cd "' .. project_root .. '" && ./build/' .. exe_name,
        direction = 'vertical',
        size = math.floor(vim.o.columns * 0.4), -- 40% of screen width
        close_on_exit = false,
        display_name = 'Run: ' .. exe_name,
        on_exit = function()
          running_processes.terminal = nil
        end,
      }
      
      running_processes.terminal = run_term
      run_term:toggle()
      vim.notify('🚀 Running: ' .. exe_name .. ' (terminal on right)', vim.log.levels.INFO)
    end

    -- Run executable in background
    local function run_executable_background()
      local exe_path = get_executable_path()
      if not exe_path then
        vim.notify('❌ No executable found in build directory.\nTry building first!', vim.log.levels.WARN)
        return
      end
      
      -- Stop any existing processes first
      stop_running_processes()
      
      local project_root = find_project_root()
      local exe_name = vim.fn.fnamemodify(exe_path, ':t')
      
      -- Run in background using vim.system (Neovim 0.10+) or fallback to job
      local cmd = { 'sh', '-c', 'cd "' .. project_root .. '" && ./build/' .. exe_name }
      
      if vim.system then
        -- Neovim 0.10+ method
        vim.system(cmd, { 
          detach = true,
        })
        vim.notify('🚀 Running: ' .. exe_name .. ' (background process)', vim.log.levels.INFO)
      else
        -- Fallback for older Neovim
        local job_id = vim.fn.jobstart(cmd, { 
          detach = true,
          on_exit = function()
            running_processes.background_job = nil
          end,
        })
        running_processes.background_job = job_id
        vim.notify('🚀 Running: ' .. exe_name .. ' (background process)', vim.log.levels.INFO)
      end
    end

    -- Build project using direct cmake commands
    local function build_project(callback)
      local project_root = find_project_root()
      
      -- Save all files first
      vim.cmd('silent! wall')
      
      vim.notify('🔨 Building project...', vim.log.levels.INFO)
      
      local build_term = Terminal:new {
        cmd = 'cd "' .. project_root .. '" && cmake --build build',
        direction = 'float',
        close_on_exit = false,
        display_name = 'Build',
        on_exit = function(term, job, exit_code, name)
          if exit_code == 0 then
            vim.notify('✅ Build successful!', vim.log.levels.INFO)
            if callback then
              vim.defer_fn(callback, 500)
            end
          else
            vim.notify('❌ Build failed (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
        end,
      }
      build_term:toggle()
    end

    -- Generate build files using direct cmake commands
    local function generate_project()
      local project_root = find_project_root()
      
      if vim.fn.filereadable(project_root .. '/CMakeLists.txt') == 0 then
        vim.notify('❌ No CMakeLists.txt found in project root!', vim.log.levels.ERROR)
        return
      end
      
      vim.notify('⚙️ Generating build files...', vim.log.levels.INFO)
      
      local gen_term = Terminal:new {
        cmd = 'cd "' .. project_root .. '" && mkdir -p build && cd build && cmake ..',
        direction = 'float',
        close_on_exit = false,
        display_name = 'Generate',
        on_exit = function(term, job, exit_code, name)
          if exit_code == 0 then
            vim.notify('✅ Generate successful!', vim.log.levels.INFO)
          else
            vim.notify('❌ Generate failed (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
        end,
      }
      gen_term:toggle()
    end

    -- Clean build
    local function clean_project()
      local project_root = find_project_root()
      
      vim.notify('🧹 Cleaning build...', vim.log.levels.INFO)
      
      local clean_term = Terminal:new {
        cmd = 'cd "' .. project_root .. '" && rm -rf build && echo "Build directory cleaned!"',
        direction = 'float',
        close_on_exit = false,
        display_name = 'Clean',
        on_exit = function(term, job, exit_code, name)
          if exit_code == 0 then
            vim.notify('✅ Clean successful!', vim.log.levels.INFO)
          else
            vim.notify('❌ Clean failed', vim.log.levels.ERROR)
          end
        end,
      }
      clean_term:toggle()
    end

    -- Quick setup for new projects
    local function quick_setup()
      local project_root = find_project_root()
      
      if vim.fn.filereadable(project_root .. '/CMakeLists.txt') == 0 then
        vim.notify('❌ No CMakeLists.txt found in project root!', vim.log.levels.ERROR)
        return
      end
      
      vim.notify('🚀 Setting up project (Generate + Build)...', vim.log.levels.INFO)
      
      local setup_term = Terminal:new {
        cmd = 'cd "' .. project_root .. '" && mkdir -p build && cd build && cmake .. && cmake --build .',
        direction = 'float',
        close_on_exit = false,
        display_name = 'Quick Setup',
        on_exit = function(term, job, exit_code, name)
          if exit_code == 0 then
            vim.notify('✅ Quick setup successful! Ready to run.', vim.log.levels.INFO)
          else
            vim.notify('❌ Quick setup failed (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
          end
        end,
      }
      setup_term:toggle()
    end

    -- Build and Run (Background) - Primary action
    local function build_and_run_bg()
      vim.notify('🔨🌟 Building and running (background)...', vim.log.levels.INFO)
      build_project(run_executable_background)
    end

    -- Build and Run (Terminal) - Alternative action
    local function build_and_run_terminal()
      vim.notify('🔨▶️ Building and running (terminal)...', vim.log.levels.INFO)
      build_project(run_executable)
    end

    -- Main menu with better UX
    vim.keymap.set('n', '<leader>m', function()
      local actions = {
        { label = '⚡ Build & Run (Background)', action = build_and_run_bg },
        { label = '🔨▶️  Build & Run (Terminal)', action = build_and_run_terminal },
        { label = '────────────────────────', action = function() end }, -- Separator
        { label = '🚀 Quick Setup (Generate + Build)', action = quick_setup },
        { label = '🔨 Build Only', action = function() build_project() end },
        { label = '▶️  Run (Terminal)', action = run_executable },
        { label = '🌟 Run (Background)', action = run_executable_background },
        { label = '⚙️  Generate', action = generate_project },
        { label = '🧹 Clean', action = clean_project },
        { label = '🛑 Stop Running Processes', action = stop_running_processes },
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
    vim.keymap.set('n', '<leader><leader>', build_and_run_bg, { desc = 'CMake: Build & Run (Background)' })
    vim.keymap.set('n', '<leader>mb', function() build_project() end, { desc = 'CMake: Build' })
    vim.keymap.set('n', '<leader>mr', run_executable, { desc = 'CMake: Run (Terminal Right)' })
    vim.keymap.set('n', '<leader>mR', run_executable_background, { desc = 'CMake: Run (Background)' })
    vim.keymap.set('n', '<leader>mg', generate_project, { desc = 'CMake: Generate' })
    vim.keymap.set('n', '<leader>mc', clean_project, { desc = 'CMake: Clean' })
    vim.keymap.set('n', '<leader>ms', quick_setup, { desc = 'CMake: Quick Setup' })
    vim.keymap.set('n', '<leader>mx', stop_running_processes, { desc = 'CMake: Stop Processes' })
  end,
}
