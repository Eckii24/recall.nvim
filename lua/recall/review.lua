local M = {}

local scheduler = require("recall.scheduler")
local storage = require("recall.storage")

---@class RecallSession
---@field deck RecallDeck
---@field queue RecallCardWithState[] due cards in review order
---@field current_index integer
---@field answer_shown boolean
---@field results table[] { card_id, rating, old_state, new_state }

--- Create a new review session from a deck
---@param deck RecallDeck
---@return RecallSession
function M.new_session(deck)
  -- Filter to only due cards
  local queue = {}
  for _, card in ipairs(deck.cards) do
    if scheduler.is_due(card.state) then
      table.insert(queue, card)
    end
  end

  -- Shuffle the queue (Fisher-Yates)
  math.randomseed(os.time() + os.clock() * 1000)
  for i = #queue, 2, -1 do
    local j = math.random(1, i)
    queue[i], queue[j] = queue[j], queue[i]
  end

  return {
    deck = deck,
    queue = queue,
    current_index = 1,
    answer_shown = false,
    results = {},
  }
end

--- Get the current card to review
---@param session RecallSession
---@return RecallCardWithState|nil
function M.current_card(session)
  if session.current_index > #session.queue then
    return nil
  end
  return session.queue[session.current_index]
end

--- Mark the current card as answer revealed
---@param session RecallSession
function M.show_answer(session)
  session.answer_shown = true
end

--- Rate the current card and advance to the next
---@param session RecallSession
---@param rating string "again"|"hard"|"good"|"easy"
---@return table new_state
function M.rate(session, rating)
  local card = session.queue[session.current_index]
  if not card then
    error("No card to rate")
  end

  local old_state = vim.deepcopy(card.state)
  local new_state = scheduler.schedule(card.state, rating)

  -- Update card state in memory
  card.state = new_state

  -- Record result
  table.insert(session.results, {
    card_id = card.id,
    rating = rating,
    old_state = old_state,
    new_state = new_state,
  })

  -- Immediately persist to storage
  local sidecar_path = storage.sidecar_path(card.source_file)
  local sidecar_data = storage.load(sidecar_path)
  storage.set_card_state(sidecar_data, card.id, new_state)

  -- Also update metadata
  sidecar_data.cards[card.id].source_file = vim.fn.fnamemodify(card.source_file, ":t")
  sidecar_data.cards[card.id].question_preview = card.question:sub(1, 80)

  storage.save(sidecar_path, sidecar_data)

  -- Advance to next card
  session.current_index = session.current_index + 1
  session.answer_shown = false

  return new_state
end

--- Check if the review session is complete
---@param session RecallSession
---@return boolean
function M.is_complete(session)
  return session.current_index > #session.queue
end

--- Get progress information
---@param session RecallSession
---@return { current: integer, total: integer, remaining: integer }
function M.progress(session)
  local total = #session.queue
  local current = math.min(session.current_index, total)
  local remaining = math.max(0, total - session.current_index + 1)

  return {
    current = current,
    total = total,
    remaining = remaining,
  }
end

return M
