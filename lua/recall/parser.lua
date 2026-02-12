local M = {}

---@class RecallCard
---@field question string      -- heading text (without #flashcard tag)
---@field answer string        -- body text below heading
---@field line_number integer  -- 1-based line of the heading
---@field heading_level integer -- 1-6
---@field id string            -- hash of question text

--- Generate a deterministic hash of a string using djb2 algorithm
--- @param str string
--- @return string
local function djb2_hash(str)
  local hash = 5381
  for i = 1, #str do
    hash = ((hash * 33) + str:byte(i)) % (2 ^ 32)
  end
  return string.format("%08x", hash)
end

--- Generate card ID from question text
--- @param question string
--- @return string
local function generate_card_id(question)
  -- Prefer vim.fn.sha256 if available, fallback to djb2
  local ok, result = pcall(vim.fn.sha256, question)
  if ok and result then
    return result
  end
  return djb2_hash(question)
end

--- Strip #flashcard tag from question text (with word boundary check)
--- @param question string
--- @return string
local function strip_flashcard_tag(question)
  -- Match #flashcard with word boundaries
  -- Pattern: whitespace or line start, then #flashcard, then whitespace or line end
  local stripped = question:gsub("%s+#flashcard%s*$", "")
  if stripped ~= question then
    return stripped
  end
  stripped = question:gsub("%s+#flashcard%s+", " ")
  return stripped
end

--- Trim leading and trailing blank lines from answer text
--- @param lines string[]
--- @param start_idx integer
--- @param end_idx integer
--- @return string
local function extract_and_trim_answer(lines, start_idx, end_idx)
  local answer_lines = {}

  for i = start_idx, end_idx do
    if i > 0 and i <= #lines then
      table.insert(answer_lines, lines[i])
    end
  end

  -- Trim leading blank lines
  while #answer_lines > 0 and answer_lines[1]:match("^%s*$") do
    table.remove(answer_lines, 1)
  end

  -- Trim trailing blank lines
  while #answer_lines > 0 and answer_lines[#answer_lines]:match("^%s*$") do
    table.remove(answer_lines)
  end

  return table.concat(answer_lines, "\n")
end

--- Parse markdown lines for flashcard data
---@param lines string[] file content as array of strings
---@param opts table parsing options
---@return RecallCard[] array of parsed cards
function M.parse(lines, opts)
  opts = opts or {}
  local auto_mode = opts.auto_mode or false
  local min_heading_level = opts.min_heading_level or 2
  local include_sub_headings = opts.include_sub_headings
  if include_sub_headings == nil then
    include_sub_headings = true
  end

  local cards = {}
  local in_frontmatter = false
  local in_code_block = false

  -- Check for YAML frontmatter at start
  if #lines > 0 and lines[1] == "---" then
    in_frontmatter = true
  end

  -- First pass: collect all heading positions and their metadata
  local headings = {}
  local fm = in_frontmatter
  local cb = in_code_block

  for idx = 1, #lines do
    local line = lines[idx]

    if fm then
      if line == "---" and idx > 1 then
        fm = false
      end
      goto scan_continue
    end

    if line:match("^```") then
      cb = not cb
      goto scan_continue
    end

    if cb then
      goto scan_continue
    end

    local level_str, heading_text = line:match("^(#+)%s+(.+)$")
    if level_str and heading_text then
      table.insert(headings, {
        line = idx,
        level = #level_str,
        text = heading_text,
      })
    end

    ::scan_continue::
  end

  -- Track which headings are consumed as sub-headings of a parent card
  local consumed = {}

  for hi, h in ipairs(headings) do
    if consumed[hi] then
      goto card_continue
    end

    local is_flashcard = false

    if auto_mode then
      is_flashcard = h.level >= min_heading_level
    else
      if h.text:match("%s#flashcard%s") or h.text:match("%s#flashcard$") then
        is_flashcard = true
      end
    end

    if not is_flashcard then
      goto card_continue
    end

    local question = h.text
    if not auto_mode then
      question = strip_flashcard_tag(h.text)
    end

    if question:match("^%s*$") then
      goto card_continue
    end

    local answer_start = h.line + 1
    local answer_end

    local next_heading_line = nil
    for nhi = hi + 1, #headings do
      local nh = headings[nhi]
      if include_sub_headings then
        -- Stop at same or higher level (lower number) heading
        if nh.level <= h.level then
          next_heading_line = nh.line
          break
        else
          -- Mark sub-headings as consumed so they don't become separate cards
          consumed[nhi] = true
        end
      else
        -- Stop at ANY next heading
        next_heading_line = nh.line
        break
      end
    end

    if next_heading_line then
      answer_end = next_heading_line - 1
    else
      answer_end = #lines
    end

    local answer = extract_and_trim_answer(lines, answer_start, answer_end)

    if answer == "" then
      goto card_continue
    end

    local card = {
      question = question,
      answer = answer,
      line_number = h.line,
      heading_level = h.level,
      id = generate_card_id(question),
    }

    table.insert(cards, card)

    ::card_continue::
  end

  return cards
end

return M
