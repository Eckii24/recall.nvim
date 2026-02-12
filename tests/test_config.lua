local config = require("recall.config")

local function test_setup_returns_opts()
  local opts = config.setup({})
  assert(type(opts) == "table", "setup should return a table")
end

local function test_default_dirs_empty()
  local opts = config.setup({})
  assert(type(opts.dirs) == "table", "dirs should be a table")
  assert(#opts.dirs == 0, "Default dirs should be empty")
end

local function test_default_auto_mode_false()
  local opts = config.setup({})
  assert(opts.defaults.auto_mode == false, "Default auto_mode should be false")
end

local function test_default_min_heading_level()
  local opts = config.setup({})
  assert(opts.defaults.min_heading_level == 2, "Default min_heading_level should be 2, got " .. opts.defaults.min_heading_level)
end

local function test_default_review_mode()
  local opts = config.setup({})
  assert(opts.review_mode == "float", "Default review_mode should be 'float', got " .. opts.review_mode)
end

local function test_default_rating_keys()
  local opts = config.setup({})
  assert(opts.keys.rating.again == "1", "again key should be '1'")
  assert(opts.keys.rating.hard == "2", "hard key should be '2'")
  assert(opts.keys.rating.good == "3", "good key should be '3'")
  assert(opts.keys.rating.easy == "4", "easy key should be '4'")
end

local function test_default_show_answer_key()
  local opts = config.setup({})
  assert(opts.keys.show_answer == "<Space>", "Default show_answer should be '<Space>', got " .. opts.keys.show_answer)
end

local function test_default_quit_key()
  local opts = config.setup({})
  assert(opts.keys.quit == "q", "Default quit should be 'q', got " .. opts.keys.quit)
end

local function test_default_initial_ease()
  local opts = config.setup({})
  assert(opts.initial_ease == 2.5, "Default initial_ease should be 2.5, got " .. opts.initial_ease)
end

local function test_default_sidecar_suffix()
  local opts = config.setup({})
  assert(opts.defaults.sidecar_suffix == ".flashcards.json",
    "Default sidecar_suffix should be '.flashcards.json', got " .. opts.defaults.sidecar_suffix)
end

local function test_setup_overrides_dirs()
  local opts = config.setup({ dirs = { "/tmp/notes" } })
  assert(#opts.dirs == 1, "dirs should have 1 entry")
  assert(opts.dirs[1].path == "/tmp/notes", "dirs[1].path should be '/tmp/notes'")
  config.setup({})
end

local function test_setup_overrides_defaults_auto_mode()
  local opts = config.setup({ defaults = { auto_mode = true } })
  assert(opts.defaults.auto_mode == true, "defaults.auto_mode should be overridden to true")
  config.setup({})
end

local function test_setup_deep_extends_rating_keys()
  local opts = config.setup({ keys = { rating = { again = "a" } } })
  assert(opts.keys.rating.again == "a", "again should be overridden to 'a'")
  assert(opts.keys.rating.hard == "2", "hard should retain default '2'")
  assert(opts.keys.rating.good == "3", "good should retain default '3'")
  assert(opts.keys.rating.easy == "4", "easy should retain default '4'")
  config.setup({})
end

local function test_setup_stores_in_opts()
  config.setup({ review_mode = "split" })
  assert(config.opts.review_mode == "split", "config.opts should be updated")
  config.setup({})
end

local function test_setup_with_nil_uses_defaults()
  local opts = config.setup(nil)
  assert(opts.review_mode == "float", "nil opts should use defaults")
  assert(opts.defaults.auto_mode == false, "nil opts should use defaults for auto_mode")
end

local function test_default_include_sub_headings()
  local opts = config.setup({})
  assert(opts.defaults.include_sub_headings == true, "Default include_sub_headings should be true")
end

local function test_default_show_session_stats()
  local opts = config.setup({})
  assert(opts.show_session_stats == "always",
    "Default show_session_stats should be 'always', got " .. opts.show_session_stats)
end

local function test_dirs_string_normalized_to_table()
  local opts = config.setup({ dirs = { "/tmp/a", "/tmp/b" } })
  assert(#opts.dirs == 2, "Should have 2 entries")
  assert(opts.dirs[1].path == "/tmp/a", "First dir path should match")
  assert(opts.dirs[2].path == "/tmp/b", "Second dir path should match")
  config.setup({})
end

local function test_dirs_table_entries_preserved()
  local opts = config.setup({ dirs = { { path = "/tmp/a", auto_mode = true } } })
  assert(#opts.dirs == 1, "Should have 1 entry")
  assert(opts.dirs[1].path == "/tmp/a", "Path should match")
  assert(opts.dirs[1].auto_mode == true, "auto_mode override should be preserved")
  config.setup({})
end

local function test_dirs_mixed_string_and_table()
  local opts = config.setup({ dirs = { "/tmp/a", { path = "/tmp/b", min_heading_level = 3 } } })
  assert(#opts.dirs == 2, "Should have 2 entries")
  assert(opts.dirs[1].path == "/tmp/a", "String entry should be normalized")
  assert(opts.dirs[2].path == "/tmp/b", "Table entry path should match")
  assert(opts.dirs[2].min_heading_level == 3, "Table entry override should be preserved")
  config.setup({})
end

local function test_get_dir_opts_returns_defaults()
  config.setup({ dirs = { "/tmp/notes" } })
  local dir_opts = config.get_dir_opts("/tmp/notes")
  assert(dir_opts.auto_mode == false, "Should return default auto_mode")
  assert(dir_opts.min_heading_level == 2, "Should return default min_heading_level")
  assert(dir_opts.include_sub_headings == true, "Should return default include_sub_headings")
  assert(dir_opts.sidecar_suffix == ".flashcards.json", "Should return default sidecar_suffix")
  config.setup({})
end

local function test_get_dir_opts_with_overrides()
  config.setup({ dirs = { { path = "/tmp/notes", auto_mode = true, min_heading_level = 3 } } })
  local dir_opts = config.get_dir_opts("/tmp/notes")
  assert(dir_opts.auto_mode == true, "auto_mode should be overridden")
  assert(dir_opts.min_heading_level == 3, "min_heading_level should be overridden")
  assert(dir_opts.include_sub_headings == true, "include_sub_headings should be default")
  config.setup({})
end

local function test_get_dir_opts_unknown_dir_returns_defaults()
  config.setup({ dirs = { "/tmp/notes" } })
  local dir_opts = config.get_dir_opts("/tmp/unknown")
  assert(dir_opts.auto_mode == false, "Unknown dir should get default auto_mode")
  assert(dir_opts.min_heading_level == 2, "Unknown dir should get default min_heading_level")
  config.setup({})
end

local function test_get_dirs_returns_expanded_paths()
  config.setup({ dirs = { "/tmp/a", { path = "/tmp/b" } } })
  local dirs = config.get_dirs()
  assert(#dirs == 2, "Should return 2 dirs")
  assert(dirs[1] == "/tmp/a", "First dir should match")
  assert(dirs[2] == "/tmp/b", "Second dir should match")
  config.setup({})
end

-- =================================================================
-- Runner
-- =================================================================

local tests = {
  { "setup returns opts", test_setup_returns_opts },
  { "default dirs empty", test_default_dirs_empty },
  { "default auto_mode false", test_default_auto_mode_false },
  { "default min_heading_level", test_default_min_heading_level },
  { "default review_mode", test_default_review_mode },
  { "default rating_keys", test_default_rating_keys },
  { "default show_answer_key", test_default_show_answer_key },
  { "default quit_key", test_default_quit_key },
  { "default initial_ease", test_default_initial_ease },
  { "default sidecar_suffix", test_default_sidecar_suffix },
  { "setup overrides dirs", test_setup_overrides_dirs },
  { "setup overrides defaults auto_mode", test_setup_overrides_defaults_auto_mode },
  { "setup deep extends rating_keys", test_setup_deep_extends_rating_keys },
  { "setup stores in opts", test_setup_stores_in_opts },
  { "setup with nil uses defaults", test_setup_with_nil_uses_defaults },
  { "default include_sub_headings", test_default_include_sub_headings },
  { "default show_session_stats", test_default_show_session_stats },
  { "dirs string normalized to table", test_dirs_string_normalized_to_table },
  { "dirs table entries preserved", test_dirs_table_entries_preserved },
  { "dirs mixed string and table", test_dirs_mixed_string_and_table },
  { "get_dir_opts returns defaults", test_get_dir_opts_returns_defaults },
  { "get_dir_opts with overrides", test_get_dir_opts_with_overrides },
  { "get_dir_opts unknown dir returns defaults", test_get_dir_opts_unknown_dir_returns_defaults },
  { "get_dirs returns expanded paths", test_get_dirs_returns_expanded_paths },
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

print(string.format("\nConfig: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
