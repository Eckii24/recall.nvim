local M = {}

local defaults = {
  defaults = {
    auto_mode = false,            -- all headings = cards
    min_heading_level = 2,        -- skip H1 in auto mode
    include_sub_headings = true,  -- include lower-level headings in answer
    sidecar_suffix = ".flashcards.json", -- per-deck sidecar suffix: <deck-name><suffix>
  },
  dirs = {},                      -- directories to scan (string or { path = ..., auto_mode = ..., ... })
  keys = {
    rating = {
      again = "1",
      hard  = "2",
      good  = "3",
      easy  = "4",
    },
    show_answer = "<Space>",
    quit = "q",
  },
  review_mode = "float",          -- "float" | "split"
  initial_ease = 2.5,
  show_session_stats = "always",  -- "always" | "on_finish" | "on_quit" | "never"
}

M.opts = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Normalize dirs: convert string entries to { path = str }
  local normalized = {}
  for _, entry in ipairs(M.opts.dirs) do
    if type(entry) == "string" then
      table.insert(normalized, { path = entry })
    elseif type(entry) == "table" then
      table.insert(normalized, entry)
    end
  end
  M.opts.dirs = normalized

  return M.opts
end

--- Get resolved options for a specific directory.
--- Merges dir-level overrides onto defaults.
--- @param dir_path string The directory path to look up
--- @return table Resolved options: { auto_mode, min_heading_level, include_sub_headings, sidecar_suffix }
function M.get_dir_opts(dir_path)
  local base = vim.tbl_extend("force", {}, M.opts.defaults)

  -- Expand the lookup path for comparison
  local expanded_lookup = vim.fn.expand(dir_path)

  for _, entry in ipairs(M.opts.dirs) do
    local entry_path = vim.fn.expand(entry.path)
    if entry_path == expanded_lookup then
      for _, key in ipairs({ "auto_mode", "min_heading_level", "include_sub_headings", "sidecar_suffix" }) do
        if entry[key] ~= nil then
          base[key] = entry[key]
        end
      end
      break
    end
  end

  return base
end

--- Get all directory paths as a flat list of expanded strings.
--- @return string[]
function M.get_dirs()
  local paths = {}
  for _, entry in ipairs(M.opts.dirs) do
    table.insert(paths, vim.fn.expand(entry.path))
  end
  return paths
end

return M
