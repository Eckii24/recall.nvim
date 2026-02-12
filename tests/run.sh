#!/usr/bin/env bash
set -e

NVIM="${NVIM:-nvim}"
INIT="tests/minimal_init.lua"

echo "Running recall.nvim tests..."
echo "=============================="

for test_file in tests/test_*.lua; do
	name=$(basename "$test_file" .lua)
	echo ""
	echo "--- $name ---"
	$NVIM --headless -u "$INIT" -c "luafile $test_file" -c "qall!" 2>&1
done

echo ""
echo "=============================="
echo "All test suites passed."
