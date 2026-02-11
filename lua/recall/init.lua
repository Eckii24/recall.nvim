local M = {}

---@param opts? RecallConfig
function M.setup(opts)
  require("recall.config").setup(opts)
end

return M
