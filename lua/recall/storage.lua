local M = {}

--- Load flashcard data from a JSON sidecar file
---@param json_path string path to .flashcards.json
---@return table data table with version and cards
function M.load(json_path)
  local default_data = { version = 1, cards = {} }

  local f = io.open(json_path, "r")
  if not f then
    return default_data
  end

  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return default_data
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    vim.notify("[recall.nvim] Warning: corrupted JSON in " .. json_path .. ", using empty state", vim.log.levels.WARN)
    return default_data
  end

  if not data.cards then
    data.cards = {}
  end
  if not data.version then
    data.version = 1
  end

  return data
end

--- Save flashcard data to a JSON sidecar file atomically
---@param json_path string path to .flashcards.json
---@param data table data table with version and cards
function M.save(json_path, data)
  local json_str = vim.json.encode(data)
  local tmp_path = json_path .. ".tmp"

  local f = io.open(tmp_path, "w")
  if not f then
    vim.notify("[recall.nvim] Error: cannot write to " .. tmp_path, vim.log.levels.ERROR)
    return
  end

  f:write(json_str)
  f:close()

  -- Atomic rename
  local ok, err = os.rename(tmp_path, json_path)
  if not ok then
    vim.notify("[recall.nvim] Error: atomic rename failed: " .. tostring(err), vim.log.levels.ERROR)
    os.remove(tmp_path)
  end
end

--- Get a card's scheduling state from the data table
---@param data table sidecar data
---@param card_id string card hash ID
---@return table|nil card_state
function M.get_card_state(data, card_id)
  if data.cards and data.cards[card_id] then
    return data.cards[card_id]
  end
  return nil
end

--- Set a card's scheduling state in the data table
---@param data table sidecar data
---@param card_id string card hash ID
---@param card_state table scheduling state
function M.set_card_state(data, card_id, card_state)
  if not data.cards then
    data.cards = {}
  end
  data.cards[card_id] = card_state
end

--- Get the sidecar JSON path for a markdown file
---@param md_file_path string path to markdown file
---@return string json_path
function M.sidecar_path(md_file_path)
  local config = require("recall.config")
  local sidecar_filename = config.opts.sidecar_filename or ".flashcards.json"
  local dir = vim.fn.fnamemodify(md_file_path, ":h")
  return dir .. "/" .. sidecar_filename
end

return M
