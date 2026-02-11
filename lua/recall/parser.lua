local M = {}

---@class RecallCard
---@field question string heading text (without #flashcard tag)
---@field answer string body text below heading
---@field line_number integer 1-based line of the heading
---@field heading_level integer 1-6
---@field id string hash of question text

--- Simple djb2 hash function for card ID generation
---@param str string
---@return string
local function hash(str)
  if vim.fn.sha256 then
    return vim.fn.sha256(str)
  end
  -- Fallback djb2 hash
  local h = 5381
  for i = 1, #str do
    h = ((h * 33) + string.byte(str, i)) % 0xFFFFFFFF
  end
  return string.format("%08x", h)
end

--- Check if a line is a heading and extract level + text
---@param line string
---@return integer|nil level
---@return string|nil text
local function parse_heading(line)
  local hashes, text = line:match("^(#+)%s+(.*)")
  if hashes and text then
    return #hashes, text
  end
  return nil, nil
end

--- Check if heading text contains the #flashcard tag (as a whole word)
---@param text string
---@return boolean
local function has_flashcard_tag(text)
  -- Match #flashcard as a whole word (not part of #flashcards or #flashcarding)
  if text:match("#flashcard$") then
    return true
  end
  if text:match("#flashcard%s") then
    return true
  end
  return false
end

--- Strip #flashcard tag from heading text
---@param text string
---@return string
local function strip_flashcard_tag(text)
  -- Remove #flashcard tag and clean up whitespace
  text = text:gsub("%s*#flashcard%s*", " ")
  text = text:match("^%s*(.-)%s*$") -- trim
  return text
end

--- Parse markdown lines into flashcards
---@param lines string[] array of lines from markdown file
---@param opts? { auto_mode?: boolean, min_heading_level?: integer }
---@return RecallCard[]
function M.parse(lines, opts)
  opts = opts or {}
  local auto_mode = opts.auto_mode or false
  local min_heading_level = opts.min_heading_level or 2

  local cards = {}
  local in_frontmatter = false
  local frontmatter_done = false
  local in_code_block = false

  -- First pass: identify card headings
  local card_starts = {} -- { line_number, heading_level, question }

  for i, line in ipairs(lines) do
    -- Handle YAML frontmatter (only at start of file)
    if i == 1 and line:match("^%-%-%-$") then
      in_frontmatter = true
      goto continue
    end
    if in_frontmatter then
      if line:match("^%-%-%-$") then
        in_frontmatter = false
        frontmatter_done = true
      end
      goto continue
    end

    -- Handle fenced code blocks
    if line:match("^```") then
      in_code_block = not in_code_block
      goto continue
    end
    if in_code_block then
      goto continue
    end

    -- Parse headings
    local level, text = parse_heading(line)
    if level and text then
      if auto_mode then
        -- Auto mode: all headings at or below min_heading_level
        if level >= min_heading_level then
          local question = text:match("^%s*(.-)%s*$")
          if question and #question > 0 then
            table.insert(card_starts, {
              line_number = i,
              heading_level = level,
              question = question,
            })
          end
        end
      else
        -- Tagged mode: only headings with #flashcard tag
        if has_flashcard_tag(text) then
          local question = strip_flashcard_tag(text)
          if #question > 0 then
            table.insert(card_starts, {
              line_number = i,
              heading_level = level,
              question = question,
            })
          end
        end
      end
    end

    ::continue::
  end

  -- Second pass: extract answers
  for idx, card_start in ipairs(card_starts) do
    local answer_lines = {}
    local start_line = card_start.line_number + 1
    local end_line = #lines

    -- Find the end of the answer: next heading of same or higher level, or next card start
    if idx < #card_starts then
      end_line = card_starts[idx + 1].line_number - 1
    end

    -- Also stop at any heading of same or higher level (even if not a card)
    local in_code = false
    for i = start_line, end_line do
      local line = lines[i]

      -- Track code blocks in answer extraction too
      if line:match("^```") then
        in_code = not in_code
        table.insert(answer_lines, line)
        goto continue_answer
      end
      if in_code then
        table.insert(answer_lines, line)
        goto continue_answer
      end

      -- Check for heading that would end this card's answer
      local level = parse_heading(line)
      if level and level <= card_start.heading_level then
        break
      end

      table.insert(answer_lines, line)
      ::continue_answer::
    end

    -- Trim leading and trailing blank lines from answer
    while #answer_lines > 0 and answer_lines[1]:match("^%s*$") do
      table.remove(answer_lines, 1)
    end
    while #answer_lines > 0 and answer_lines[#answer_lines]:match("^%s*$") do
      table.remove(answer_lines)
    end

    local answer = table.concat(answer_lines, "\n")

    table.insert(cards, {
      question = card_start.question,
      answer = answer,
      line_number = card_start.line_number,
      heading_level = card_start.heading_level,
      id = hash(card_start.question),
    })
  end

  return cards
end

return M
