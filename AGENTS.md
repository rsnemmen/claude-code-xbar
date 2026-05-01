# AGENTS.md - Claude Code Rate Limit Plugin

## Project Overview

A SwiftBar/xbar plugin written in bash shell script with embedded Python for JSON parsing. Displays Claude Code API rate limit utilization in the macOS menu bar, polling every 5 minutes. No compilation or external packages required.

---

## Build / Lint / Test Commands

This project has **no build system** - it's a standalone shell script.

### Running the Script

```bash
# Make executable (already set)
chmod +x claude_code.5m.sh

# Run directly
./claude_code.5m.sh

# Run with specific environment variables
VAR_SHOW_7D=true VAR_COLORS=true ./claude_code.5m.sh

# Test with SwiftBar/xbar installed
# Copy to SwiftBar plugins folder: ~/Library/Application Support/SwiftBar/Plugins/
```

### Linting

```bash
shellcheck claude_code.5m.sh
```

### Testing

**No automated tests exist.** Manual verification steps:

1. Ensure Claude Code is installed and signed in
2. Run the script and verify menu bar output:
   ```bash
   ./claude_code.5m.sh | head -5
   ```
3. Check SwiftBar/xbar dropdown renders correctly:
   ```bash
   ./claude_code.5m.sh | grep -c "^---"
   ```

---

## Code Style Guidelines

### Shell Script Conventions

- **Shebang**: `#!/usr/bin/env bash`
- **Variables**: UPPER_CASE with `${VAR:-default}` fallback pattern
- **Functions**: Use `local` for function-scope variables
- **Exit codes**: Use `exit 0` for success, `exit 1` for errors (or specific codes for different errors)
- **Error handling**: Redirect stderr to `/dev/null` for expected failures (e.g., missing credentials)
- **Quoting**: Always quote variable expansions (`printf '%s' "$var"`) to preserve whitespace

### Formatting

- Indentation: 2 spaces (no tabs)
- Max line length: 100 characters (soft limit)
- Use blank lines to separate logical sections
- Comment sections with `=== SECTION NAME ===` format
- Use `printf '%s'` instead of `echo` for arbitrary strings

### Naming Conventions

- **Script files**: `{name}.{interval}.sh` (e.g., `claude_code.5m.sh`)
- **Variables**: Descriptive, prefixed with context:
  - `VAR_*` for user-configurable settings
  - `UTIL_*` for raw utilization floats
  - `PCT_*` for rounded integer percentages
  - `RESET_*` for ISO timestamp strings
  - `BAR_*` for ASCII progress bars
  - `COLOR_*` for hex color codes
- **Functions**: snake_case (e.g., `time_until()`, `color_for_pct()`, `make_bar()`, `make_icon()`)

### Imports / Dependencies

- **System utilities only**: `curl`, `python3`, `security` (Keychain access), `stat`
- **Python stdlib only**: `json`, `datetime`, `sys`, `sys.stderr`
- Avoid external tools like `jq`, `bc`, `awk` - use Python for parsing instead
- Always use `python3` (not `python`)

### Error Handling

- Check for required credentials/inputs before API calls
- Provide user-friendly error messages in menu bar output
- Use appropriate emoji indicators: `!` for errors
- Include error details in dropdown or stderr, not in title
- HTTP errors: display error with status code in dropdown
- On auth errors (401), clear token cache so next run re-reads from Keychain

### Types

- Shell: strings and integers only
- Python: use explicit type handling (e.g., `str(v) if v is not None else default`)
- Percentages: round to integers using `round(float(...))`
- Timestamps: parse ISO 8601 format in Python, display as relative time

### API Conventions

- **OAuth token**: Retrieved from macOS Keychain using `security find-generic-password`
- **Keychain service name**: `Claude Code-credentials`
- **API endpoint**: `https://api.anthropic.com/api/oauth/usage`
- **Headers**: Bearer token + `anthropic-beta: oauth-2025-04-20`
- **Response format**: JSON with `five_hour`, `seven_day`, `seven_day_opus` windows

### Caching

- Token cache: `/tmp/.claude_swiftbar_token` (15-minute TTL)
- Response cache: `/tmp/.claude_swiftbar_cache` (5-minute TTL, matches poll interval)
- Use `date -u +%s` for Unix timestamps, `stat -f %m` for macOS file modification time

### SwiftBar/xbar Plugin Metadata

Place at top of script in comments:
```
#<xbar.title>Title</xbar.title>
#<xbar.version>1.0</xbar.version>
#<xbar.author>Name</xbar.author>
#<xbar.desc>Description</xbar.desc>
#<xbar.dependencies>tool1,tool2</xbar.dependencies>
#<xbar.var>type(VAR_NAME="default"):Description</xbar.var>
```

### Output Format

- **Menu bar line (bar mode)**: ` | templateImage=BASE64_PNG` (space-only text, dynamic PNG from `make_icon`)
- **Menu bar line (text mode)**: `percentage | templateImage=... color=...`
- **Dropdown sections**: Separated by `---`
- **Refresh action**: `Refresh | refresh=true`
- **Colors**: Hex codes (e.g., `#FF0000`, `#FFD700`, `#888888`)
- **Color thresholds**: dark amber `#CC8800` at ≥70%, dark red `#CC0000` at ≥90%

---

## Project Structure

```
.
├── claude_code.5m.sh    # Main plugin script
├── README.md            # User documentation
├── CLAUDE.md            # Claude Code guidance
├── AGENTS.md            # AI agent guidance
└── logo.png             # App icon (base64 in script)
```

---

## Configuration

User-configurable variables (defined at top, also editable via SwiftBar):

| Variable | Default | Description |
|----------|---------|-------------|
| VAR_SHOW_BARS | true | Show dynamic dual progress bar icon (5h top, 7d bottom); false reverts to static Claude logo with text |
| VAR_SHOW_7D | false | Show 7-day window in title as text (e.g. 45%/23%); only applies when VAR_SHOW_BARS=false |
| VAR_COLORS | true | Color-code at warning (≥70%) and critical (≥90%) levels; only applies when VAR_SHOW_BARS=false |
| VAR_SHOW_RESET | true | Show time-until-reset in dropdown |
| VAR_SHOW_PACE | false | Show expected uniform-pace usage bar under the 7d window |

---

## Common Tasks

### Adding a new rate limit window

1. Add `get_val('window_name', 'utilization')` and `get_val('window_name', 'resets_at')` to the Python parsing block
2. Extract variables using `sed -n 'Np'` (append two new lines to the existing sequence)
3. Call `format_pct`, `make_bar`, `color_for_pct`, and `time_until` following the existing pattern
4. Emit the new dropdown section between `---` separators

### Modifying error messages

All error paths use `show_error "message"`. Error states occur after credential retrieval and after the API call. The title shows `!`; the message appears in the dropdown.

### Changing polling interval

Rename file: `claude_code.5m.sh` → `claude_code.15m.sh` (xbar reads interval from filename)

---

## Notes for AI Agents

- This is a simple, single-file project - avoid over-engineering
- No type checking or tests needed - verify manually
- Keep dependencies minimal - Python stdlib only
- Follow existing patterns in the script for consistency
- Test any changes with SwiftBar/xbar before committing
- Use `printf '%s'` instead of `echo` for reliability
- All JSON parsing and date arithmetic goes in inline Python
