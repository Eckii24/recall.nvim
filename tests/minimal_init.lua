-- Minimal init for running tests with `nvim --headless -u tests/minimal_init.lua`
-- Adds the plugin to the runtime path so require("recall.*") works.

vim.opt.rtp:prepend(".")

-- Stub snacks.nvim (not needed for unit tests)
package.preload["snacks"] = function()
  local snacks = {}

  snacks.win = function(opts)
    local buf = vim.api.nvim_create_buf(false, true)
    if opts and opts.bo then
      for k, v in pairs(opts.bo) do
        vim.bo[buf][k] = v
      end
    end
    return {
      buf = buf,
      close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end,
    }
  end

  snacks.picker = {
    pick = function(opts)
      if opts and opts._test_callback then
        opts._test_callback(opts)
      end
    end,
  }

  return snacks
end

-- Initialize config with defaults
require("recall.config").setup({})
