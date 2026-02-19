# Claude Usage — SwiftBar/xbar Plugin

A single shell script that displays Claude Code API rate limit utilization in the macOS menu bar, polling every 5 minutes. No compilation, no Xcode, no external packages required.

```
45% | ████████░░░░░░░░░░░░
```

---

## Background

This script is a lightweight companion to [ClaudeMeter](https://github.com/rsnemmen/claude-meter), a full native macOS app built in Swift that monitors Claude Code usage. The shell script follows the same approach as [`poe_balance.1h.sh`](poe_balance.1h.sh) — a SwiftBar plugin for Poe API credits — and borrows its structure, credential-retrieval pattern, and output format. The result is something you can drop into your SwiftBar plugins folder and run immediately, without any build step.

---

## Requirements

- macOS 12.3 or later
- [SwiftBar](https://github.com/swiftbar/SwiftBar) or [xbar](https://xbarapp.com)
- Claude Code CLI installed and signed in (credentials stored in Keychain automatically)
- `curl` and `python3` (both ship with macOS)

---

## Installation

1. Install SwiftBar (if you haven't already):

        brew install swiftbar

2. Copy the script to your SwiftBar plugins folder:

        cp claude_usage.5m.sh ~/path/to/swiftbar/plugins/

3. Make it executable:

        chmod +x ~/path/to/swiftbar/plugins/claude_usage.5m.sh

4. Click **Refresh All** in SwiftBar or wait for the next poll cycle.

No API key setup is needed. The script reads the OAuth token that Claude Code already stores in your macOS Keychain under `"Claude Code-credentials"`.

---

## Output

### Menu bar title

By default, only the 5-hour window utilization is shown:

```
45%
```

With `VAR_SHOW_7D=true`, both the 5-hour and 7-day windows are shown in compact form:

```
45%/23%
```

Color coding (when `VAR_COLORS=true`):

| Utilization | Color |
|---|---|
| < 75% | default (no color) |
| ≥ 75% | yellow (`#FFD700`) |
| ≥ 90% | red (`#FF0000`) |

When both windows are shown, the title uses the more urgent color of the two.

### Dropdown

```
5h window
5h: 45% ████████░░░░░░░░░░░░
Resets in: 2h 30m
---
7d window
7d: 23% ████░░░░░░░░░░░░░░░░
Resets in: 4d 2h
---
7d Opus window
7d Opus: 10% ██░░░░░░░░░░░░░░░░░░
Resets in: 4d 2h
---
Refresh
```

---

## Configuration

Edit the `xbar.var` lines at the top of the script, or use SwiftBar's built-in variable editor (right-click the menu bar item → **Preferences**).

| Variable | Default | Description |
|---|---|---|
| `VAR_SHOW_7D` | `false` | Also show the 7-day window in the title (`45%/23%`) |
| `VAR_COLORS` | `true` | Color-code the title at warning and critical thresholds |
| `VAR_SHOW_RESET` | `true` | Show time-until-reset for each window in the dropdown |

---

## Error states

| Condition | Menu bar display |
|---|---|
| Claude Code not signed in | `⚠️ No Credentials` |
| OAuth token expired | `⚠️ Token Expired` |
| Network or API error | `⚠️ API Error (NNN)` |
| Unexpected API response | `⚠️ Parse Error` |

If credentials are missing, sign in to Claude Code (`claude login`) and the script will pick them up on the next poll.

---

## How it works

1. Reads the Claude Code OAuth token from the macOS Keychain using the `security` CLI — the same approach used in ClaudeMeter's `KeychainService.swift` — which avoids triggering a Keychain password prompt.
2. Calls `GET https://api.anthropic.com/api/oauth/usage` with the bearer token and the `anthropic-beta: oauth-2025-04-20` header.
3. Parses the three rate-limit windows (`five_hour`, `seven_day`, `seven_day_opus`) from the JSON response using an inline `python3` snippet.
4. Formats utilization percentages, ASCII progress bars, and countdown timers, then prints SwiftBar-formatted output.

All JSON parsing and date arithmetic is handled by `python3` (stdlib only). No `jq`, no `bc`, no third-party packages.

---

## Polling interval

The `5m` in the filename tells SwiftBar to run the script every 5 minutes. To change the interval, rename the file — for example, `claude_usage.1m.sh` for once per minute or `claude_usage.15m.sh` for every 15 minutes.

---

## Related projects

- **ClaudeMeter** — the full native macOS app this script lives alongside: adaptive polling, circuit breaker, notifications, settings UI, and more, all in Swift with no external dependencies.
- **poe_balance** — the SwiftBar plugin for Poe API credits that served as the structural template for this script.
