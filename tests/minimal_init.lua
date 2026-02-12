-- Minimal init for running tests with `nvim --headless -u tests/minimal_init.lua`
-- Adds the plugin to the runtime path so require("recall.*") works.

vim.opt.rtp:prepend(".")

-- Stub snacks.nvim (not needed for unit tests)
package.preload["snacks"] = function()
  return {
    win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      return {
        buf = buf,
        close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end,
      }
    end,
  }
end

-- Initialize config with defaults
require("recall.config").setup({})
