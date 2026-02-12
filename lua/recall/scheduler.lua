local M = {}

--- Get today's date as ISO 8601 string
local function get_today()
  return os.date("%Y-%m-%d")
end

--- Map rating string to SM-2 quality value
--- @param rating string One of: "again", "hard", "good", "easy"
--- @return number quality (0, 2, 3, or 5)
local function rating_to_quality(rating)
  local quality_map = {
    again = 0,
    hard = 2,
    good = 3,
    easy = 5,
  }
  return quality_map[rating] or 0
end

--- Calculate date N days from a given date
--- @param date_str string ISO 8601 date string (YYYY-MM-DD)
--- @param days number Number of days to add
--- @return string New date as ISO 8601 string
local function add_days(date_str, days)
  if days == 0 then
    return date_str
  end

  local y, m, d = date_str:match("(%d+)-(%d+)-(%d+)")
  y = tonumber(y) or 0
  m = tonumber(m) or 0
  d = tonumber(d) or 0

  local timestamp = os.time({ year = y, month = m, day = d, hour = 0, min = 0, sec = 0 }) --[[@as integer]]
  timestamp = timestamp + (days * 86400)

  return os.date("%Y-%m-%d", timestamp) --[[@as string]]
end

--- Create a new card with initial state
--- @return table Card state: { ease = 2.5, interval = 0, reps = 0, due = today }
function M.new_card()
  return {
    ease = 2.5,
    interval = 0,
    reps = 0,
    due = get_today(),
  }
end

--- Check if a card is due for review
--- @param card_state table Card state with `due` field
--- @return boolean True if card.due <= today
function M.is_due(card_state)
  local today = get_today()
  return card_state.due <= today
end

--- Apply SM-2 algorithm to update card state based on rating
---
--- SM-2 Algorithm:
--- if quality < 3:
---     interval = 1
---     reps = 0
--- else:
---     if reps == 0: interval = 1
---     elif reps == 1: interval = 6
---     else: interval = ceil(interval * ease)
---     reps = reps + 1
---
--- ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
--- ease = max(1.3, ease)
--- due = today + interval days
---
--- @param card_state table Card state: { ease, interval, reps, due }
--- @param rating string One of: "again", "hard", "good", "easy"
--- @return table New card state
function M.schedule(card_state, rating)
  local quality = rating_to_quality(rating)
  local ease = card_state.ease
  local interval = card_state.interval
  local reps = card_state.reps

  if quality < 3 then
    interval = 1
    reps = 0
  else
    if reps == 0 then
      interval = 1
    elseif reps == 1 then
      interval = 6
    else
      interval = math.ceil(interval * ease)
    end
    reps = reps + 1
  end

  ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))

  ease = math.max(1.3, ease)

  local today = get_today()
  local due = add_days(today, interval)

  return {
    ease = ease,
    interval = interval,
    reps = reps,
    due = due,
  }
end

return M
