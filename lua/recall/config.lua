local M = {}

local defaults = {
  dirs = {},                    -- directories to scan
  auto_mode = false,            -- all headings = cards
  min_heading_level = 2,        -- skip H1 in auto mode
  include_sub_headings = true,  -- include lower-level headings in answer (stops at same/higher level)
  review_mode = "float",        -- "float" | "split"
  rating_keys = {
    again = "1",
    hard  = "2",
    good  = "3",
    easy  = "4",
  },
  show_answer_key = "<Space>",
  quit_key = "q",
  initial_ease = 2.5,
  sidecar_filename = ".flashcards.json",
  show_session_stats = "always", -- "always" | "on_finish" | "on_quit" | "never"
}

M.opts = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", defaults, opts or {})
  return M.opts
end

return M
