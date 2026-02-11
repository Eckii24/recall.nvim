local M = {}

---@class RecallConfig
---@field dirs string[] directories to scan for flashcard files
---@field auto_mode boolean if true, all headings become cards (no #flashcard needed)
---@field min_heading_level integer skip headings above this level in auto mode (default: 2, skips H1)
---@field review_mode string "float" | "split"
---@field rating_keys table keymaps during review
---@field show_answer_key string key to reveal answer
---@field quit_key string key to quit review
---@field initial_ease number SM-2 initial ease factor
---@field sidecar_filename string name of sidecar JSON file

---@type RecallConfig
local defaults = {
  dirs = {},
  auto_mode = false,
  min_heading_level = 2,
  review_mode = "float",
  rating_keys = {
    again = "1",
    hard = "2",
    good = "3",
    easy = "4",
  },
  show_answer_key = "<Space>",
  quit_key = "q",
  initial_ease = 2.5,
  sidecar_filename = ".flashcards.json",
}

---@type RecallConfig
M.opts = {}

---@param opts? RecallConfig
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
