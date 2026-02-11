local M = {}

function M.check()
  vim.health.start("recall.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim >= 0.11")
  else
    vim.health.error("Neovim >= 0.11 required", { "Update Neovim to 0.11 or later" })
  end

  -- Check snacks.nvim
  local ok_snacks = pcall(require, "snacks")
  if ok_snacks then
    vim.health.ok("snacks.nvim available")
  else
    vim.health.warn("snacks.nvim not found (required for floating window and picker)", {
      "Install snacks.nvim: https://github.com/folke/snacks.nvim",
    })
  end

  -- Check configured directories
  local config = require("recall.config")
  if config.opts and config.opts.dirs then
    if #config.opts.dirs == 0 then
      vim.health.info("No directories configured (will use cwd)")
    else
      for _, dir in ipairs(config.opts.dirs) do
        if vim.fn.isdirectory(dir) == 1 then
          vim.health.ok("Directory exists: " .. dir)
        else
          vim.health.warn("Directory not found: " .. dir, {
            "Create the directory or update config.dirs",
          })
        end
      end
    end
  else
    vim.health.info("Plugin not configured yet (call require('recall').setup())")
  end

  -- Check JSON encoding/decoding
  local ok_json = pcall(vim.json.encode, { test = true })
  if ok_json then
    vim.health.ok("vim.json available")
  else
    vim.health.error("vim.json not available", { "This requires Neovim 0.10+" })
  end
end

return M
