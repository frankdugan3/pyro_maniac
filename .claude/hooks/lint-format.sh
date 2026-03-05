#!/usr/bin/env bash
# Hook: lint and format files after Write/Edit

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process files that exist (in case of failed writes)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

cd "$(echo "$INPUT" | jq -r '.cwd')"

case "$FILE_PATH" in
  *.css|*.js|*.mjs|*.ts|*.json|*.html|*.md)
    # 1. Auto-fix with ast-grep (if fixable rules exist)
    ast-grep scan --update-all "$FILE_PATH" 2>/dev/null || true

    # 2. Format with prettier
    prettier --write "$FILE_PATH" 2>/dev/null

    # 3. Lint (report remaining violations as errors)
    VIOLATIONS=$(ast-grep scan "$FILE_PATH" 2>&1) || true
    if [[ -n "$VIOLATIONS" ]]; then
      echo "$VIOLATIONS" >&2
      exit 2
    fi
    ;;

  *.ex|*.exs)
    # 1. Auto-fix with ast-grep (if fixable rules exist)
    ast-grep scan --update-all "$FILE_PATH" 2>/dev/null || true

    # 2. Format with mix format
    mix format "$FILE_PATH" 2>/dev/null

    # 3. Lint with credo
    mix credo "$FILE_PATH" 2>&1

    # 4. Lint (report remaining ast-grep violations as errors)
    VIOLATIONS=$(ast-grep scan "$FILE_PATH" 2>&1) || true
    if [[ -n "$VIOLATIONS" ]]; then
      echo "$VIOLATIONS" >&2
      exit 2
    fi
    ;;
esac

exit 0
