local M = {}

local parser = require("recall.parser")
local storage = require("recall.storage")
local scheduler = require("recall.scheduler")

---@class RecallCardWithState : RecallCard
---@field ease number
---@field interval integer
---@field reps integer
---@field due string

---@class RecallDeck
---@field name string          -- filename without extension
---@field filepath string      -- full path to markdown file
---@field cards RecallCardWithState[]
---@field total integer
---@field due integer          -- cards due today

-- Cache: { [filepath] = { mtime_sec = number, parsed_cards = RecallCard[] } }
local parse_cache = {}

--- Get modification time of a file
--- @param filepath string
--- @return number mtime_sec (0 if file doesn't exist)
local function get_mtime(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat and stat.mtime.sec or 0
end

--- Get parsed cards from cache or parse file
--- @param filepath string
--- @param opts table
--- @return RecallCard[]
local function get_cached_or_parse(filepath, opts)
  local mtime = get_mtime(filepath)

  if parse_cache[filepath] and parse_cache[filepath].mtime_sec == mtime then
    return parse_cache[filepath].parsed_cards
  end

  local lines = vim.fn.readfile(filepath)
  local cards = parser.parse(lines, opts)

  parse_cache[filepath] = {
    mtime_sec = mtime,
    parsed_cards = cards,
  }

  return cards
end

--- Merge parsed cards with scheduling data from sidecar JSON
--- @param parsed_cards RecallCard[]
--- @param sidecar_data table { version = 1, cards = { [card_id] = card_state } }
--- @return RecallCardWithState[]
local function merge_cards_with_state(parsed_cards, sidecar_data)
  local cards_with_state = {}

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
      ease = state.ease,
      interval = state.interval,
      reps = state.reps,
      due = state.due,
    }

    table.insert(cards_with_state, card_with_state)
  end

  return cards_with_state
end

--- Count cards that are due for review
--- @param cards RecallCardWithState[]
--- @return integer
local function count_due_cards(cards)
  local count = 0
  for _, card in ipairs(cards) do
    if scheduler.is_due(card) then
      count = count + 1
    end
  end
  return count
end

--- Scan a single markdown file
--- @param filepath string Full path to markdown file
--- @param opts table|nil Parsing options (auto_mode, min_heading_level)
--- @return RecallDeck
function M.scan_file(filepath, opts)
  opts = opts or {}

  local parsed_cards = get_cached_or_parse(filepath, opts)

  local sidecar_path = storage.sidecar_path(filepath)
  local sidecar_data = storage.load(sidecar_path)

  local cards_with_state = merge_cards_with_state(parsed_cards, sidecar_data)

  local name = vim.fn.fnamemodify(filepath, ":t:r")

  local deck = {
    name = name,
    filepath = filepath,
    cards = cards_with_state,
    total = #cards_with_state,
    due = count_due_cards(cards_with_state),
  }

  return deck
end

--- Scan multiple directories for markdown files
--- @param dirs string[] Array of directory paths to scan
--- @param opts table|nil Parsing options (auto_mode, min_heading_level)
--- @return RecallDeck[] Array of decks
function M.scan(dirs, opts)
  opts = opts or {}
  local decks = {}

  for _, dir in ipairs(dirs) do
    local files = vim.fs.find(function(name)
      return name:match("%.md$")
    end, {
      path = dir,
      type = "file",
      limit = math.huge,
    })

    for _, filepath in ipairs(files) do
      local deck = M.scan_file(filepath, opts)
      table.insert(decks, deck)
    end
  end

  return decks
end

--- Scan current working directory for markdown files
--- @param opts table|nil Parsing options (auto_mode, min_heading_level)
--- @return RecallDeck[] Array of decks
function M.scan_cwd(opts)
  local cwd = vim.fn.getcwd()
  return M.scan({ cwd }, opts)
end

return M
