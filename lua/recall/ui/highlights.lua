local M = {}

--- Define default highlight groups for recall.nvim
--- Uses `default = true` so user colorschemes and overrides take precedence.
function M.setup()
  local set = vim.api.nvim_set_hl

  -- Window chrome
  set(0, "RecallTitle", { link = "Title", default = true })
  set(0, "RecallFooter", { link = "Comment", default = true })
  set(0, "RecallSeparator", { link = "FloatBorder", default = true })

  -- Content
  set(0, "RecallQuestion", { link = "markdownH2", default = true })
  set(0, "RecallAnswer", { link = "Normal", default = true })
  set(0, "RecallDeckName", { link = "Special", default = true })
  set(0, "RecallProgress", { link = "Comment", default = true })

  -- Actions
  set(0, "RecallButtonLabel", { link = "Special", default = true })
  set(0, "RecallComplete", { link = "DiagnosticOk", default = true })
end

return M
