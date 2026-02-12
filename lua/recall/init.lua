local M = {}

function M.setup(opts)
  local config = require("recall.config")
  M.state = {
    opts = config.setup(opts),
  }
  return M.state.opts
end

return M
