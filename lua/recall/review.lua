local scheduler = require('recall.scheduler')
local storage = require('recall.storage')

local M = {}

--- Shuffle an array in place
--- @param arr table Array to shuffle
local function shuffle(arr)
  math.randomseed(os.time())
  for i = #arr, 2, -1 do
    local j = math.random(i)
    arr[i], arr[j] = arr[j], arr[i]
  end
end

--- Create a new review session from a deck
--- @param deck RecallDeck Deck with cards to review
--- @return RecallSession Session object
function M.new_session(deck)
  -- Filter to only due cards
  local queue = {}
  for _, card in ipairs(deck.cards) do
    if scheduler.is_due(card.state) then
      table.insert(queue, card)
    end
  end

  -- Shuffle the queue
  shuffle(queue)

  return {
    deck = deck,
    queue = queue,
    current_index = 1,
    answer_shown = false,
    results = {},
  }
end

--- Get the current card in the session
--- @param session RecallSession Session object
--- @return RecallCardWithState|nil Current card or nil if complete
function M.current_card(session)
  if session.current_index > #session.queue then
    return nil
  end
  return session.queue[session.current_index]
end

--- Mark the current card's answer as shown
--- @param session RecallSession Session object
function M.show_answer(session)
  session.answer_shown = true
end

--- Rate the current card, compute new state, persist immediately, and advance
--- @param session RecallSession Session object
--- @param rating string One of: "again", "hard", "good", "easy"
--- @return table New card state
function M.rate(session, rating)
  local card = M.current_card(session)
  if not card then
    error("No card to rate - session is complete")
  end

  -- Compute new state using scheduler
  local old_state = card.state
  local new_state = scheduler.schedule(old_state, rating)

  -- Store the rating result
  table.insert(session.results, {
    card_id = card.id,
    rating = rating,
    old_state = old_state,
    new_state = new_state,
  })

  -- Immediately persist to storage
  local json_path = storage.sidecar_path(session.deck.source_file)
  local data = storage.load(json_path)
  storage.set_card_state(data, card.id, new_state)
  storage.save(json_path, data)

  card.state = new_state

  -- Advance to next card
  session.current_index = session.current_index + 1
  session.answer_shown = false

  return new_state
end

--- Check if the session is complete
--- @param session RecallSession Session object
--- @return boolean True if all cards have been reviewed
function M.is_complete(session)
  return session.current_index > #session.queue
end

--- Get progress information for the session
--- @param session RecallSession Session object
--- @return table Progress info: { current = int, total = int, remaining = int }
function M.progress(session)
  local total = #session.queue
  local current = session.current_index
  local remaining = math.max(0, total - current + 1)

  return {
    current = current,
    total = total,
    remaining = remaining,
  }
end

return M
