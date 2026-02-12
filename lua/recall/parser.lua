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

  local cards = {}
  local in_frontmatter = false
  local in_code_block = false

  -- Check for YAML frontmatter at start
  if #lines > 0 and lines[1] == "---" then
    in_frontmatter = true
  end

  local i = 1
  while i <= #lines do
    local line = lines[i]

    -- Handle YAML frontmatter
    if in_frontmatter then
      if line == "---" then
        in_frontmatter = false
      end
      i = i + 1
      goto continue
    end

    -- Handle code blocks
    if line:match("^```") then
      in_code_block = not in_code_block
      i = i + 1
      goto continue
    end

    -- Skip lines inside code blocks
    if in_code_block then
      i = i + 1
      goto continue
    end

    -- Try to extract heading
    local level_str, heading_text = line:match("^(#+)%s+(.+)$")

    if level_str and heading_text then
      local heading_level = #level_str

      -- Determine if this heading should become a card
      local is_flashcard = false

      if auto_mode then
        -- Auto mode: heading is a card if at or below min_heading_level
        is_flashcard = heading_level >= min_heading_level
      else
        -- Tagged mode: heading must contain #flashcard tag
        -- Check for #flashcard with word boundaries (not part of another word)
        if heading_text:match("%s#flashcard%s") or heading_text:match("%s#flashcard$") then
          is_flashcard = true
        end
      end

      if is_flashcard then
        -- Extract question (strip #flashcard tag in tagged mode)
        local question = heading_text
        if not auto_mode then
          question = strip_flashcard_tag(heading_text)
        end

        -- Skip cards with empty question (only #flashcard tag)
        if question:match("^%s*$") then
          i = i + 1
          goto continue
        end

        -- Extract answer: all text until next heading of same or higher level (lower level number)
        local answer_start = i + 2  -- Next line after heading
        local answer_end = i + 1    -- Default to current heading if no content

        -- Find the end of answer (next heading of same or higher level)
        local j = i + 1
        while j <= #lines do
          local next_level_str, _ = lines[j]:match("^(#+)%s+")
          if next_level_str then
            local next_level = #next_level_str
            if next_level <= heading_level then
              answer_end = j - 1
              break
            end
          end
          if j == #lines then
            answer_end = #lines
          end
          j = j + 1
        end

        local answer = extract_and_trim_answer(lines, answer_start, answer_end)

        -- Create card
        local card = {
          question = question,
          answer = answer,
          line_number = i,
          heading_level = heading_level,
          id = generate_card_id(question),
        }

        table.insert(cards, card)
      end
    end

    i = i + 1
    ::continue::
  end

  return cards
end

return M
