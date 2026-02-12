local picker = require("recall.picker")

local function test_pick_deck_calls_snacks_picker()
  local picker_called = false

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        picker_called = true
        assert(opts.title == "Select Deck", "Title should be 'Select Deck'")
        assert(opts.items ~= nil, "Items should be provided")
        assert(opts.confirm ~= nil, "Confirm callback should be provided")
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  local decks = {
    { name = "deck1", filepath = "/tmp/d1.md", cards = {}, total = 3, due = 2 },
    { name = "deck2", filepath = "/tmp/d2.md", cards = {}, total = 5, due = 1 },
  }

  picker.pick_deck(decks, function() end)
  assert(picker_called, "Snacks.picker.pick should have been called")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local function test_pick_deck_items_sorted_by_due_desc()
  local captured_items = nil

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        captured_items = opts.items
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  local decks = {
    { name = "low", filepath = "/tmp/low.md", cards = {}, total = 10, due = 1 },
    { name = "high", filepath = "/tmp/high.md", cards = {}, total = 10, due = 5 },
    { name = "mid", filepath = "/tmp/mid.md", cards = {}, total = 10, due = 3 },
  }

  picker.pick_deck(decks, function() end)

  assert(captured_items ~= nil, "Items should be captured")
  assert(#captured_items == 3, "Should have 3 items")
  assert(captured_items[1].deck.name == "high", "First item should be 'high' (most due)")
  assert(captured_items[2].deck.name == "mid", "Second item should be 'mid'")
  assert(captured_items[3].deck.name == "low", "Third item should be 'low' (least due)")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local function test_pick_deck_item_text_format()
  local captured_items = nil

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        captured_items = opts.items
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  local decks = {
    { name = "mydeck", filepath = "/tmp/mydeck.md", cards = {}, total = 10, due = 3 },
  }

  picker.pick_deck(decks, function() end)

  assert(captured_items[1].text:find("mydeck") ~= nil, "Text should contain deck name")
  assert(captured_items[1].text:find("3 due") ~= nil, "Text should contain due count")
  assert(captured_items[1].text:find("10 total") ~= nil, "Text should contain total count")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local function test_confirm_calls_picker_close()
  local close_called = false
  local captured_confirm = nil

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        captured_confirm = opts.confirm
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  local decks = {
    { name = "test", filepath = "/tmp/test.md", cards = {}, total = 1, due = 1 },
  }

  picker.pick_deck(decks, function() end)

  assert(captured_confirm ~= nil, "Confirm callback should be captured")

  local mock_picker = {
    close = function() close_called = true end,
  }
  local mock_item = { deck = decks[1] }

  captured_confirm(mock_picker, mock_item)
  assert(close_called, "picker:close() MUST be called in confirm callback")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local function test_confirm_calls_on_select_via_schedule()
  local selected_deck = nil
  local captured_confirm = nil

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        captured_confirm = opts.confirm
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  local test_deck = { name = "sched", filepath = "/tmp/sched.md", cards = {}, total = 1, due = 1 }

  picker.pick_deck({ test_deck }, function(deck)
    selected_deck = deck
  end)

  local mock_picker = { close = function() end }
  captured_confirm(mock_picker, { deck = test_deck })

  vim.wait(100, function() return selected_deck ~= nil end)
  assert(selected_deck ~= nil, "on_select should be called after confirm")
  assert(selected_deck.name == "sched", "Selected deck should match")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local function test_confirm_handles_nil_item()
  local close_called = false
  local select_called = false
  local captured_confirm = nil

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local snacks = {}
    snacks.picker = {
      pick = function(opts)
        captured_confirm = opts.confirm
      end,
    }
    snacks.win = function() return { buf = 0, close = function() end } end
    return snacks
  end

  picker.pick_deck({
    { name = "x", filepath = "/tmp/x.md", cards = {}, total = 1, due = 1 },
  }, function()
    select_called = true
  end)

  local mock_picker = { close = function() close_called = true end }
  captured_confirm(mock_picker, nil)

  assert(close_called, "picker:close() should still be called even with nil item")
  vim.wait(50, function() return select_called end)
  assert(not select_called, "on_select should NOT be called when item is nil")

  package.loaded["snacks"] = nil
  package.preload["snacks"] = function()
    local s = {}
    s.win = function(opts)
      local buf = vim.api.nvim_create_buf(false, true)
      if opts and opts.bo then for k, v in pairs(opts.bo) do vim.bo[buf][k] = v end end
      return { buf = buf, close = function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end }
    end
    s.picker = { pick = function(opts) if opts and opts._test_callback then opts._test_callback(opts) end end }
    return s
  end
end

local tests = {
  { "pick_deck calls snacks picker", test_pick_deck_calls_snacks_picker },
  { "pick_deck items sorted by due desc", test_pick_deck_items_sorted_by_due_desc },
  { "pick_deck item text format", test_pick_deck_item_text_format },
  { "confirm calls picker:close()", test_confirm_calls_picker_close },
  { "confirm calls on_select via schedule", test_confirm_calls_on_select_via_schedule },
  { "confirm handles nil item", test_confirm_handles_nil_item },
}

local passed, failed = 0, 0
for _, test in ipairs(tests) do
  local name, fn = test[1], test[2]
  local ok, err = pcall(fn)
  if ok then
    print("  PASS: " .. name)
    passed = passed + 1
  else
    print("  FAIL: " .. name .. " - " .. tostring(err))
    failed = failed + 1
  end
end

print(string.format("\nPicker: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
