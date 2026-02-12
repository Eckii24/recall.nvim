local M = {}

local config = require("recall.config")

function M.check()
  vim.health.start("recall.nvim")

  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim version >= 0.11")
  else
    local version = vim.version()
    vim.health.error(
      string.format(
        "Neovim version %d.%d.%d is too old (required: 0.11+)",
        version.major,
        version.minor,
        version.patch
      )
    )
  end

  local ok = pcall(require, "snacks")
  if ok then
    vim.health.ok("snacks.nvim is installed")
  else
    vim.health.error("snacks.nvim not found (required for UI)")
  end

  local dirs = config.opts.dirs or {}
  if #dirs == 0 then
    vim.health.warn("No directories configured (set dirs in setup())")
  else
    local all_exist = true
    local all_readable = true

    for _, dir in ipairs(dirs) do
      local stat = vim.uv.fs_stat(dir)
      if not stat then
        vim.health.error(string.format("Directory does not exist: %s", dir))
        all_exist = false
      elseif stat.type ~= "directory" then
        vim.health.error(string.format("Path is not a directory: %s", dir))
        all_exist = false
      else
        local readable = vim.uv.fs_access(dir, "R")
        if not readable then
          vim.health.error(string.format("Directory not readable: %s", dir))
          all_readable = false
        end
      end
    end

    if all_exist and all_readable then
      vim.health.ok(string.format("All %d configured directories exist and are readable", #dirs))
    end
  end

  local test_file = "/tmp/recall_health_test.json"
  local test_data = { test = true, timestamp = os.time() }

  local write_ok = pcall(function()
    local encoded = vim.json.encode(test_data)
    local f = io.open(test_file, "w")
    if not f then
      error("Failed to open test file for writing")
    end
    f:write(encoded)
    f:close()
  end)

  if not write_ok then
    vim.health.error("JSON write test failed (cannot write to /tmp)")
    return
  end

  local read_ok, read_data = pcall(function()
    local f = io.open(test_file, "r")
    if not f then
      error("Failed to open test file for reading")
    end
    local content = f:read("*all")
    f:close()
    return vim.json.decode(content)
  end)

  pcall(os.remove, test_file)

  if read_ok and read_data and read_data.test == true then
    vim.health.ok("JSON write/read test passed")
  else
    vim.health.error("JSON read test failed")
  end
end

return M
