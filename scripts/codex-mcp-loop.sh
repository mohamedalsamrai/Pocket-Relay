#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while true; do
  if just --justfile "$project_root/justfile" --working-directory "$project_root" codex-mcp; then
    exit 0
  fi

  status=$?
  echo "codex-mcp exited with status $status; restarting in 2s..." >&2
  sleep 2
done
