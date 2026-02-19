# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A single-file SwiftBar/xbar plugin (`claude_usage.5m.sh`) that displays Claude Code API rate limit utilization in the macOS menu bar. No build system, no external dependencies beyond `curl` and `python3` (both ship with macOS).

## Running and Testing

```bash
# Make executable and run directly
chmod +x claude_usage.5m.sh
./claude_usage.5m.sh

# Requires Claude Code signed in (token stored in Keychain under "Claude Code-credentials")

# Optional linting
shellcheck claude_usage.5m.sh
```

There are no automated tests. Verify changes manually with SwiftBar installed.

## Architecture

The script executes in four sequential phases:

1. **Credential retrieval** — reads the Claude Code OAuth token from macOS Keychain via `security find-generic-password`, then extracts the `accessToken` with an inline Python snippet.
2. **API call** — `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer` and `anthropic-beta: oauth-2025-04-20`.
3. **JSON parsing** — a single inline Python block extracts `utilization` and `resets_at` from the three windows (`five_hour`, `seven_day`, `seven_day_opus`), printing one value per line; shell reads them back with `sed -n 'Np'`.
4. **Output** — prints SwiftBar-formatted text: menu bar title on line 1, dropdown sections separated by `---`.

## Conventions

- Use `printf '%s'` instead of `echo` when handling arbitrary strings.
- All JSON parsing and date arithmetic goes in inline Python (stdlib only — no `jq`, `bc`, `awk`).
- User-configurable variables use the `VAR_` prefix and `${VAR_NAME:-default}` fallback pattern.
- Section variables follow context prefixes: `UTIL_*` for raw utilization floats, `PCT_*` for rounded integers, `RESET_*` for ISO timestamps, `BAR_*` for ASCII bars.
- Script filename encodes the polling interval: `claude_usage.5m.sh` → every 5 minutes.

## SwiftBar Output Format

- Title line: `text | templateImage=BASE64 color=#RRGGBB`
- Dropdown separator: `---`
- Refresh action: `Refresh | refresh=true`
- Muted labels: `| color=#888888`
- Color thresholds: yellow `#FFD700` at ≥75%, red `#FF0000` at ≥90%
