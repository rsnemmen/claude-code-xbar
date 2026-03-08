# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A single-file SwiftBar/xbar plugin (`claude_code.5m.sh`) that displays Claude Code API rate limit utilization in the macOS menu bar. No build system, no external dependencies beyond `curl` and `python3` (both ship with macOS).

## Running and Testing

```bash
# Make executable and run directly
chmod +x claude_code.5m.sh
./claude_code.5m.sh

# Requires Claude Code signed in (token stored in Keychain under "Claude Code-credentials")

# Optional linting
shellcheck claude_code.5m.sh
```

There are no automated tests. Verify changes manually with SwiftBar installed.

## Architecture

The script executes in four sequential phases:

1. **Credential retrieval** — reads the Claude Code OAuth token from macOS Keychain via `security find-generic-password`, then extracts the `accessToken` with an inline Python snippet. Token is cached at `/tmp/.claude_swiftbar_token` (TTL 15 min) to avoid repeated Keychain reads.
2. **API call** — `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer` and `anthropic-beta: oauth-2025-04-20`. Response is cached at `/tmp/.claude_swiftbar_cache` (TTL 5 min, matching the poll interval).
3. **JSON parsing** — a single inline Python block extracts `utilization` and `resets_at` from the three windows (`five_hour`, `seven_day`, `seven_day_opus`), printing one value per line; shell reads them back with `sed -n 'Np'`.
4. **Output** — prints SwiftBar-formatted text: menu bar title on line 1, dropdown sections separated by `---`.

Helper functions: `show_error` (emit error state and exit), `format_pct` (float → rounded int), `time_until` (ISO 8601 → human countdown), `color_for_pct` (threshold coloring), `make_bar` (20-char ASCII progress bar).

## User-Configurable Variables

Exposed as xbar plugin variables (editable via xbar UI or set as env vars before running):

| Variable | Default | Effect |
|---|---|---|
| `VAR_SHOW_7D` | `false` | Show 7-day utilization in title as `5h%/7d%` |
| `VAR_COLORS` | `true` | Color-code title at warning/critical thresholds |
| `VAR_SHOW_RESET` | `true` | Show time-until-reset in dropdown |

## Conventions

- Use `printf '%s'` instead of `echo` when handling arbitrary strings.
- All JSON parsing and date arithmetic goes in inline Python (stdlib only — no `jq`, `bc`, `awk`).
- User-configurable variables use the `VAR_` prefix and `${VAR_NAME:-default}` fallback pattern.
- Section variables follow context prefixes: `UTIL_*` for raw utilization floats, `PCT_*` for rounded integers, `RESET_*` for ISO timestamps, `BAR_*` for ASCII bars.
- Script filename encodes the polling interval: `claude_code.5m.sh` → every 5 minutes.

## SwiftBar Output Format

- Title line: `text | templateImage=BASE64 color=#RRGGBB`
- Dropdown separator: `---`
- Refresh action: `Refresh | refresh=true`
- Muted labels: `| color=#888888`
- Color thresholds: yellow `#FFD700` at ≥75%, red `#FF0000` at ≥90%
