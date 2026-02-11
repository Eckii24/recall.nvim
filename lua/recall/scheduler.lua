local M = {}

--- Rating to SM-2 quality mapping (Anki-style)
local quality_map = {
  again = 0,
  hard = 2,
  good = 3,
  easy = 5,
}

--- Create a new card state with initial values
---@return { ease: number, interval: number, reps: number, due: string }
function M.new_card()
  return {
    ease = 2.5,
    interval = 0,
    reps = 0,
    due = os.date("%Y-%m-%d"),
  }
end

--- Schedule a card based on its current state and a rating
---@param card_state { ease: number, interval: number, reps: number, due: string }
---@param rating string one of "again", "hard", "good", "easy"
---@return { ease: number, interval: number, reps: number, due: string }
function M.schedule(card_state, rating)
  local quality = quality_map[rating]
  if quality == nil then
    error("Invalid rating: " .. tostring(rating))
  end

  local ease = card_state.ease
  local interval = card_state.interval
  local reps = card_state.reps

  if quality < 3 then
    -- Lapse: reset interval and reps
    interval = 1
    reps = 0
  else
    -- Successful recall
    if reps == 0 then
      interval = 1
    elseif reps == 1 then
      interval = 6
    else
      interval = math.ceil(interval * ease)
    end
    reps = reps + 1
  end

  -- Update ease factor
  ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
  ease = math.max(1.3, ease)

  -- Calculate due date
  local d = os.date("*t")
  local today = os.time({ year = d.year, month = d.month, day = d.day, hour = 0 })
  local due_time = today + (interval * 86400)
  local due = os.date("%Y-%m-%d", due_time)

  return {
    ease = ease,
    interval = interval,
    reps = reps,
    due = due,
  }
end

--- Check if a card is due for review
---@param card_state { ease: number, interval: number, reps: number, due: string }
---@return boolean
function M.is_due(card_state)
  local today = os.date("%Y-%m-%d")
  return card_state.due <= today
end

return M
