#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: run_godot_checked.sh <godot command and arguments...>" >&2
  exit 2
fi

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

"$@" 2>&1 | tee "$log_file"

if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to load resource|ERROR: Parameter "material" is null' "$log_file"; then
  echo "::error::Godot emitted a script, resource, or material error." >&2
  exit 1
fi
