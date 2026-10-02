#!/bin/sh
# Strips AI attribution lines from commit messages. Install per repo:
#   cp apps/statbatt/scripts/commit-msg-hook.sh .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
f="$1"
grep -v -i -E '^(Co-Authored-By:.*(Claude|anthropic)|Claude-Session:|.*Generated with .*Claude)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
