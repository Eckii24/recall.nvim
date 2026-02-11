local M = {}

local parser = require("recall.parser")
local storage = require("recall.storage")
local scheduler = require("recall.scheduler")
local config = require("recall.config")

---@class RecallCardWithState
---@field question string
---@field answer string
---@field line_number integer
---@field heading_level integer
---@field id string
---@field state { ease: number, interval: number, reps: number, due: string }
---@field source_file string

---@class RecallDeck
---@field name string filename without extension
---@field filepath string full path to markdown file
---@field cards RecallCardWithState[]
---@field total integer
---@field due integer cards due today

-- In-memory cache: filepath → { mtime, cards }
local cache = {}

--- Scan a single markdown file and return a deck
---@param filepath string
---@param opts? { auto_mode?: boolean, min_heading_level?: integer }
---@return RecallDeck
function M.scan_file(filepath, opts)
  opts = opts or {}
  local auto_mode = opts.auto_mode
  if auto_mode == nil then
    auto_mode = config.opts.auto_mode or false
  end
  local min_heading_level = opts.min_heading_level or config.opts.min_heading_level or 2

  -- Check mtime for caching
  local stat = vim.uv.fs_stat(filepath)
  local mtime = stat and stat.mtime and stat.mtime.sec or 0

  local parsed_cards
  if cache[filepath] and cache[filepath].mtime == mtime then
    parsed_cards = cache[filepath].cards
  else
    local lines = vim.fn.readfile(filepath)
    parsed_cards = parser.parse(lines, {
      auto_mode = auto_mode,
      min_heading_level = min_heading_level,
    })
    cache[filepath] = { mtime = mtime, cards = parsed_cards }
  end

  -- Load sidecar data
  local sidecar_path = storage.sidecar_path(filepath)
  local sidecar_data = storage.load(sidecar_path)

  -- Merge cards with scheduling state
  local cards_with_state = {}
  local due_count = 0

  for _, card in ipairs(parsed_cards) do
    local state = storage.get_card_state(sidecar_data, card.id)
    if not state then
      state = scheduler.new_card()
    end

    local card_with_state = {
      question = card.question,
      answer = card.answer,
      line_number = card.line_number,
      heading_level = card.heading_level,
      id = card.id,
      state = state,
      source_file = filepath,
    }

    if scheduler.is_due(state) then
      due_count = due_count + 1
    end

    table.insert(cards_with_state, card_with_state)
  end

  local name = vim.fn.fnamemodify(filepath, ":t:r")

  return {
    name = name,
    filepath = filepath,
    cards = cards_with_state,
    total = #cards_with_state,
    due = due_count,
  }
end

--- Scan directories for markdown files and return decks
---@param dirs string[] directories to scan
---@param opts? { auto_mode?: boolean, min_heading_level?: integer }
---@return RecallDeck[]
function M.scan(dirs, opts)
  local decks = {}

  for _, dir in ipairs(dirs) do
    local md_files = vim.fs.find(function(name)
      return name:match("%.md$")
    end, { path = dir, type = "file", limit = math.huge })

    for _, filepath in ipairs(md_files) do
      local deck = M.scan_file(filepath, opts)
      if deck.total > 0 then
        table.insert(decks, deck)
      end
    end
  end

  -- Sort by name
  table.sort(decks, function(a, b)
    return a.name < b.name
  end)

  return decks
end

--- Scan current working directory
---@param opts? { auto_mode?: boolean, min_heading_level?: integer }
---@return RecallDeck[]
function M.scan_cwd(opts)
  return M.scan({ vim.fn.getcwd() }, opts)
end

--- Clear the file cache
function M.clear_cache()
  cache = {}
end

return M
