# AGENTS.md - Claude Usage

## Project Overview

A SwiftBar/xbar plugin written in bash shell script with embedded Python for JSON parsing. Displays Claude Code API rate limit utilization in the macOS menu bar, polling every 5 minutes. No compilation or external packages required.

---

## Build / Lint / Test Commands

This project has **no build system** - it's a standalone shell script.

### Running the Script

```bash
# Make executable (already set)
chmod +x claude_usage.5m.sh

# Run directly
./claude_usage.5m.sh

# Test with SwiftBar/xbar installed
# Copy to SwiftBar plugins folder: ~/Library/Application Support/SwiftBar/Plugins/
```

### Linting

No formal linter configured. For shell script quality, consider:

```bash
# shellcheck (optional)
brew install shellcheck
shellcheck claude_usage.5m.sh
```

### Testing

**No automated tests exist.** To test manually:

1. Ensure Claude Code is installed and signed in
2. Run the script and verify menu bar output
3. Check SwiftBar/xbar dropdown renders correctly

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

- Indentation: 2 spaces
- Max line length: 100 characters (soft limit)
- Use blank lines to separate logical sections
- Comment sections with `=== SECTION NAME ===` format

### Naming Conventions

- **Script files**: `{name}.{interval}.sh` (e.g., `claude_usage.5m.sh`)
- **Variables**: Descriptive, prefixed with context (e.g., `VAR_` for user-configurable, `UTIL_` for values)
- **Functions**: snake_case (e.g., `time_until()`, `color_for_pct()`)

### Imports / Dependencies

- **System utilities only**: `curl`, `python3`, `security` (Keychain access)
- **Python stdlib only**: `json`, `datetime`, `sys`, `sys.stderr`
- Avoid external tools like `jq`, `bc`, `awk` - use Python for parsing instead

### Error Handling

- Check for required credentials/inputs before API calls
- Provide user-friendly error messages in menu bar output
- Use appropriate emoji indicators: `⚠️` for errors
- Include error details in dropdown or stderr, not in title
- HTTP errors: display `⚠️ API Error (NNN)` with status code

### Types

- Shell: strings and integers only
- Python: use explicit type handling (e.g., `str(v) if v is not None else default`)
- Percentages: round to integers using `round(float(...))`

### API Conventions

- **OAuth token**: Retrieved from macOS Keychain using `security find-generic-password`
- **API endpoint**: `https://api.anthropic.com/api/oauth/usage`
- **Headers**: Bearer token + `anthropic-beta: oauth-2025-04-20`
- **Response format**: JSON with `five_hour`, `seven_day`, `seven_day_opus` windows

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

- **Menu bar line**: `percentage | templateImage=... color=...`
- **Dropdown sections**: Separated by `---`
- **Refresh action**: `Refresh | refresh=true`
- **Colors**: Hex codes (e.g., `#FF0000`, `#FFD700`, `#888888`)

---

## Project Structure

```
.
├── claude_usage.5m.sh    # Main plugin script
├── README.md             # User documentation
└── logo.png              # App icon (base64 in script)
```

---

## Configuration

User-configurable variables (defined at top, also editable via SwiftBar):

| Variable | Default | Description |
|----------|---------|-------------|
| VAR_SHOW_7D | false | Show 7-day window in title |
| VAR_COLORS | true | Color-code at warning/critical thresholds |
| VAR_SHOW_RESET | true | Show time-until-reset in dropdown |

---

## Common Tasks

### Adding a new rate limit window

1. Add parsing in Python section (lines 75-97)
2. Extract variable using `sed -n 'Np'` (line 105+)
3. Add to display in dropdown section

### Modifying error messages

Error states are handled at script top after credential retrieval and after API call. Menu bar displays short message; details go to dropdown or stderr.

### Changing polling interval

Rename file: `claude_usage.5m.sh` → `claude_usage.15m.sh` (xbar reads interval from filename)

---

## Notes for AI Agents

- This is a simple, single-file project - avoid over-engineering
- No type checking or tests needed - verify manually
- Keep dependencies minimal - Python stdlib only
- Follow existing patterns in the script for consistency
- Test any changes with SwiftBar/xbar before committing
