local M = {}

---@param json_path string — path to .flashcards.json file
---@return table — { version = 1, cards = { [card_id] = card_state, ... } }
function M.load(json_path)
  -- Try to read the file
  local f = io.open(json_path, "r")
  if not f then
    -- File doesn't exist, return empty state
    return { version = 1, cards = {} }
  end

  -- Read entire file content
  local content = f:read("*a")
  f:close()

  -- Safely decode JSON
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    -- Corrupted JSON — log warning and return empty state
    vim.notify(
      "Warning: Corrupted JSON in " .. json_path .. ", starting fresh",
      vim.log.levels.WARN
    )
    return { version = 1, cards = {} }
  end

  -- Validate structure
  if not data or not data.cards or type(data.cards) ~= "table" then
    vim.notify(
      "Warning: Invalid JSON structure in " .. json_path .. ", starting fresh",
      vim.log.levels.WARN
    )
    return { version = 1, cards = {} }
  end

  return data
end

---@param json_path string — path to .flashcards.json file
---@param data table — { version = 1, cards = { [card_id] = card_state, ... } }
function M.save(json_path, data)
  -- Encode to JSON
  local json_str = vim.json.encode(data)

  -- Atomic write: write to .tmp first
  local tmp_path = json_path .. ".tmp"
  local f, err = io.open(tmp_path, "w")
  if not f then
    vim.notify("Error writing to " .. tmp_path .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  f:write(json_str)
  f:close()

  -- Atomically rename .tmp to final path
  local ok, rename_err = os.rename(tmp_path, json_path)
  if not ok then
    vim.notify(
      "Error renaming " .. tmp_path .. " to " .. json_path .. ": " .. tostring(rename_err),
      vim.log.levels.ERROR
    )
    return false
  end

  return true
end

---@param data table — { version = 1, cards = { [card_id] = card_state, ... } }
---@param card_id string — unique card identifier
---@return table|nil — card_state if found, nil otherwise
function M.get_card_state(data, card_id)
  if not data or not data.cards then
    return nil
  end
  return data.cards[card_id]
end

---@param data table — { version = 1, cards = { [card_id] = card_state, ... } }
---@param card_id string — unique card identifier
---@param card_state table — { ease, interval, reps, due, source_file, question_preview }
function M.set_card_state(data, card_id, card_state)
  if not data.cards then
    data.cards = {}
  end
  data.cards[card_id] = card_state
end

---@param md_file_path string — path to markdown file (e.g., "/path/to/file.md")
---@return string — path to sidecar JSON (e.g., "/path/to/.flashcards.json")
function M.sidecar_path(md_file_path)
  -- Get directory and filename
  local dir = vim.fn.fnamemodify(md_file_path, ":h")
  -- Return directory + default sidecar filename
  return dir .. "/.flashcards.json"
end

return M
