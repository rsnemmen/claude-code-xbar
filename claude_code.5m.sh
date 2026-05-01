#!/usr/bin/env bash
#<xbar.title>Claude Usage</xbar.title>
#<xbar.version>1.0</xbar.version>
#<xbar.author>Rodrigo Nemmen da Silva</xbar.author>
#<xbar.desc>Display Claude Code API rate limit utilization</xbar.desc>
#<xbar.dependencies>curl,python3</xbar.dependencies>
#<xbar.image>https://raw.githubusercontent.com/rsnemmen/claude-usage/refs/heads/main/SCR-20260219-jges.png</xbar.image>

# User variables
# ================
#<xbar.var>boolean(VAR_SHOW_7D="false"): Also show 7-day window in title (e.g. 45%/23%).</xbar.var>
#<xbar.var>boolean(VAR_COLORS="true"): Color-code title at warning (>75%) and critical (>90%) levels.</xbar.var>
#<xbar.var>boolean(VAR_SHOW_RESET="true"): Show time-until-reset for each window in the dropdown.</xbar.var>
#<xbar.var>boolean(VAR_SHOW_BARS="true"): Show dynamic dual progress bar icon (5h top, 7d bottom) instead of the Claude logo.</xbar.var>
#<xbar.var>boolean(VAR_SHOW_PACE="false"): Show expected (uniform-pace) usage bar under the 7d window.</xbar.var>

SHOW_7D="${VAR_SHOW_7D:-false}"
COLORS="${VAR_COLORS:-true}"
SHOW_RESET="${VAR_SHOW_RESET:-true}"
SHOW_BARS="${VAR_SHOW_BARS:-true}"
SHOW_PACE="${VAR_SHOW_PACE:-false}"

CLAUDE_ICON="iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAAXNSR0IArs4c6QAAAHhlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAABIAAAAAQAAAEgAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAABKgAwAEAAAAAQAAABIAAAAAqSaGYgAAAAlwSFlzAAALEwAACxMBAJqcGAAAAdJJREFUOBGV0z1IVWEYB3Cv2ZAVlQUpWDnYJqZBREPU1tISBo1OBkEfWBGNQhTR1iwu2hIENdYUVBRBBjXVUEZRYBLah2CD3X5/O/cQ14vRA7/zPO/Hec857zmnqakuqtVqM11U6ob+r2mBQ3zjYu1MdR/3aKv1/TObvI9ffKqdKA+zwOYsIPewv+FiBrbSWky8oU6cKtrX1C+Kuludi3xkaX65oI4WJnlOLx185TUZmyi0yk9JXGf5Puo8zjzfGeACiSPcJu0xErno+vJO6guDu3hAYpwZnvCY3G1ijp76cxu2TTxP7qwWi0WRlzBCP0OMcou2isMWq43wky/MME0vZ9lELaqKjK0m8/ICHjLW4jDPSzrYQDt9JBb/pPKYua+4zyTvmapUKgvy8nCXnWSPpsjj1GJKcZm7TJN4R3vuqAwd6zSGyfdzh2fkEbrIFkQ3A+Tx+lnLbPkdWGSvjnFWcYJOhhjlMD84wCO2c9QjfZaXorlWyLlCFtrNLJcYZAdznCPfzgcmyLe1U24cBrfxhmOZIednvVrUg+rEHvJzH0x/wzB4hisZlNeQ/+p00c7ncpOTDU/+u9Ok8gWoN/KW7FEZ2n9vSdm/YuGkdrJ/K8ZvZcjUYTq3RuAAAAAASUVORK5CYII="

# === Helper: show error with logo and warning ===

show_error() {
  local message="$1"
  echo "! | templateImage=${CLAUDE_ICON}"
  echo "---"
  echo "${message}"
  echo "---"
  echo "Refresh | refresh=true"
  exit 0
}

USAGE_CACHE="/tmp/.claude_swiftbar_cache"
TOKEN_CACHE="/tmp/.claude_swiftbar_token"
CACHE_TTL=300   # 5 minutes — matches poll interval
TOKEN_TTL=900   # 15 minutes

# === Get token (cached) ===

TOKEN=""
if [ -f "$TOKEN_CACHE" ]; then
  cache_age=$(( $(date -u +%s) - $(stat -f %m "$TOKEN_CACHE" 2>/dev/null || echo 0) ))
  if [ "$cache_age" -lt "$TOKEN_TTL" ]; then
    TOKEN="$(cat "$TOKEN_CACHE" 2>/dev/null)"
  fi
fi

if [ -z "$TOKEN" ]; then
  RAW_CREDS="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)"
  if [ -z "$RAW_CREDS" ]; then
    show_error "No Claude Code credentials found in Keychain. Sign in to Claude Code first."
  fi
  TOKEN="$(printf '%s' "$RAW_CREDS" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read().strip())
    if 'claudeAiOauth' in d:
        print(d['claudeAiOauth']['accessToken'])
    elif 'accessToken' in d:
        print(d['accessToken'])
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null)"
  if [ -z "$TOKEN" ]; then
    show_error "Could not parse Claude Code credentials."
  fi
  printf '%s' "$TOKEN" > "$TOKEN_CACHE"
fi

# === Load usage from cache or fetch from API ===

parsed=""

if [ -f "$USAGE_CACHE" ]; then
  cache_age=$(( $(date -u +%s) - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0) ))
  if [ "$cache_age" -lt "$CACHE_TTL" ]; then
    parsed="$(cat "$USAGE_CACHE" 2>/dev/null)"
  fi
fi

if [ -z "$parsed" ]; then
  response="$(curl -s --connect-timeout 5 --max-time 10 -w "\n%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Accept: application/json" \
    "https://api.anthropic.com/api/oauth/usage")"

  http_code="$(printf '%s\n' "$response" | tail -n 1)"
  body="$(printf '%s\n' "$response" | sed '$d')"

  if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
    show_error "No internet connection."
  fi

  if [ "$http_code" = "401" ]; then
    # Token may be stale — clear cache so next run re-reads from Keychain
    rm -f "$TOKEN_CACHE"
    show_error "Token expired. Please sign in to Claude Code again."
  elif [ "$http_code" = "429" ]; then
    show_error "Usage API rate limited. Will retry shortly."
  elif [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    show_error "API error: HTTP $http_code"
  fi

  parsed="$(printf '%s' "$body" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    def get_val(window, field, default='0'):
        try:
            w = d.get(window)
            if not w:
                return default
            v = w.get(field)
            return str(v) if v is not None else default
        except Exception:
            return default
    print(get_val('five_hour',      'utilization', '0'))
    print(get_val('seven_day',      'utilization', '0'))
    print(get_val('seven_day_opus', 'utilization', '0'))
    print(get_val('five_hour',      'resets_at',   ''))
    print(get_val('seven_day',      'resets_at',   ''))
    print(get_val('seven_day_opus', 'resets_at',   ''))
except Exception as e:
    sys.stderr.write(str(e) + '\n')
    sys.exit(1)
" 2>/dev/null)"

  if [ -z "$parsed" ]; then
    show_error "Could not parse API response"
  fi

  printf '%s\n' "$parsed" > "$USAGE_CACHE"
fi

UTIL_5H="$(      printf '%s\n' "$parsed" | sed -n '1p')"
UTIL_7D="$(      printf '%s\n' "$parsed" | sed -n '2p')"
UTIL_7D_OPUS="$( printf '%s\n' "$parsed" | sed -n '3p')"
RESET_5H="$(     printf '%s\n' "$parsed" | sed -n '4p')"
RESET_7D="$(     printf '%s\n' "$parsed" | sed -n '5p')"
RESET_7D_OPUS="$(printf '%s\n' "$parsed" | sed -n '6p')"

format_pct() {
  python3 -c "print(round(float('${1:-0}')))" 2>/dev/null || echo "0"
}

PCT_5H="$(      format_pct "$UTIL_5H")"
PCT_7D="$(      format_pct "$UTIL_7D")"
PCT_7D_OPUS="$( format_pct "$UTIL_7D_OPUS")"

# === Helper: human-readable countdown from ISO 8601 timestamp ===

time_until() {
  local ts="$1"
  [ -z "$ts" ] && echo "?" && return
  python3 -c "
from datetime import datetime, timezone
ts = '${ts}'
try:
    if ts.endswith('Z'):
        ts = ts[:-1] + '+00:00'
    reset = datetime.fromisoformat(ts)
    now = datetime.now(timezone.utc)
    diff = reset - now
    secs = diff.total_seconds()
    if secs <= 0:
        print('now')
    else:
        days  = int(secs // 86400)
        hours = int((secs % 86400) // 3600)
        mins  = int((secs % 3600) // 60)
        if days > 0:
            print(f'{days}d {hours}h')
        elif hours > 0:
            print(f'{hours}h {mins}m')
        else:
            print(f'{mins}m')
except Exception:
    print('?')
" 2>/dev/null || echo "?"
}

# === Helper: expected utilization at uniform pace ===
# Returns what % of the window should have been used by now, assuming uniform consumption.
# pace_pct <resets_at_iso8601> <window_days>

pace_pct() {
  local ts="$1"
  local days="$2"
  [ -z "$ts" ] && echo "0" && return
  python3 -c "
from datetime import datetime, timezone, timedelta
ts = '${ts}'
days = ${days}
try:
    if ts.endswith('Z'):
        ts = ts[:-1] + '+00:00'
    resets_at = datetime.fromisoformat(ts)
    now = datetime.now(timezone.utc)
    window = timedelta(days=days)
    start = resets_at - window
    elapsed = (now - start).total_seconds()
    total = window.total_seconds()
    pct = max(0.0, min(100.0, elapsed / total * 100))
    print(round(pct))
except Exception:
    print(0)
" 2>/dev/null || echo "0"
}

# === Helper: color for a given percentage ===

color_for_pct() {
  local pct=$1
  if [ "$COLORS" = "true" ]; then
    [ "$pct" -ge 90 ] 2>/dev/null && echo "#CC0000" && return
    [ "$pct" -ge 70 ] 2>/dev/null && echo "#CC8800" && return
  fi
  echo ""
}

# === Helper: ASCII progress bar (20 chars) ===

make_bar() {
  local pct="${1:-0}"
  local width=20
  local filled
  filled=$(python3 -c "print(min(int(round(${pct} * ${width} / 100)), ${width}))" 2>/dev/null || echo "0")
  local bar=""
  local i=1
  while [ "$i" -le "$width" ]; do
    if [ "$i" -le "$filled" ]; then
      bar="${bar}█"
    else
      bar="${bar}░"
    fi
    i=$((i + 1))
  done
  echo "$bar"
}

# === Helper: dynamic dual progress bar icon ===

make_icon() {
  local pct5h="${1:-0}" pct7d="${2:-0}"
  python3 -c "
import struct, zlib, base64

def decode_png(b64):
    data = base64.b64decode(b64)
    pos = 8
    idat = []
    w = h = 0
    while pos < len(data):
        n = struct.unpack('>I', data[pos:pos+4])[0]
        tag = data[pos+4:pos+8]
        cd = data[pos+8:pos+8+n]
        pos += 12 + n
        if tag == b'IHDR':
            w, h = struct.unpack('>II', cd[:8])
        elif tag == b'IDAT':
            idat.append(cd)
        elif tag == b'IEND':
            break
    raw = zlib.decompress(b''.join(idat))
    bpp, stride = 4, w * 4
    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
        return a if pa <= pb and pa <= pc else (b if pb <= pc else c)
    rows, prev, idx = [], bytes(stride), 0
    for _ in range(h):
        ft = raw[idx]; idx += 1
        s = bytearray(raw[idx:idx+stride]); idx += stride
        if ft == 1:
            for i in range(bpp, stride): s[i] = (s[i] + s[i-bpp]) & 0xff
        elif ft == 2:
            for i in range(stride): s[i] = (s[i] + prev[i]) & 0xff
        elif ft == 3:
            for i in range(stride):
                s[i] = (s[i] + ((s[i-bpp] if i >= bpp else 0) + prev[i]) // 2) & 0xff
        elif ft == 4:
            for i in range(stride):
                s[i] = (s[i] + paeth(s[i-bpp] if i >= bpp else 0, prev[i], prev[i-bpp] if i >= bpp else 0)) & 0xff
        rows.append([(s[i*bpp], s[i*bpp+1], s[i*bpp+2], s[i*bpp+3]) for i in range(w)])
        prev = bytes(s)
    return rows, w, h

def resize_nn(rows, sw, sh, dw, dh):
    out = []
    for ty in range(dh):
        sy = min(int(round(ty * sh / dh)), sh - 1)
        row = []
        for tx in range(dw):
            sx = min(int(round(tx * sw / dw)), sw - 1)
            row.append(rows[sy][sx])
        out.append(row)
    return out

def make_png(w, h, rows_rgba):
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(c[4:]) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    raw = b''
    for row in rows_rgba:
        raw += b'\x00'
        for (r,g,b,a) in row:
            raw += bytes([r,g,b,a])
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', ihdr)
            + chunk(b'IDAT', zlib.compress(raw))
            + chunk(b'IEND', b''))

W, H = 42, 14
ICON_W, ICON_H = 20, 14  # downsampled logo size (fills full canvas height)
ICON_Y = 0               # top row of logo
BAR_X, BAR_W = 22, 20   # bars start at col 22, span 20px; cols 20-21 are a gap

p5 = min(max(int(round(${pct5h})), 0), 100)
p7 = min(max(int(round(${pct7d})), 0), 100)

logo_rows, sw, sh = decode_png('${CLAUDE_ICON}')
logo = resize_nn(logo_rows, sw, sh, ICON_W, ICON_H)
logo = [[(0, 0, 0, a) for (r, g, b, a) in row] for row in logo]

fill5 = int(round(p5 * BAR_W / 100))
fill7 = int(round(p7 * BAR_W / 100))
FG    = (0, 0, 0, 255)
EMPTY = (0, 0, 0, 60)
CLEAR = (0, 0, 0, 0)

rows = []
for ri in range(H):
    row = []
    for ci in range(W):
        if ci < ICON_W:
            li = ri - ICON_Y
            row.append(logo[li][ci] if 0 <= li < ICON_H else CLEAR)
        elif ci < BAR_X:
            row.append(CLEAR)
        else:
            bc = ci - BAR_X
            if 1 <= ri <= 5:
                row.append(FG if bc < fill5 else EMPTY)
            elif 9 <= ri <= 13:
                row.append(FG if bc < fill7 else EMPTY)
            else:
                row.append(CLEAR)
    rows.append(row)

print(base64.b64encode(make_png(W, H, rows)).decode())
" 2>/dev/null
}

# === Build menu bar title ===

COLOR_5H="$(color_for_pct "$PCT_5H")"
COLOR_7D="$(color_for_pct "$PCT_7D")"

# For title, use the "most urgent" color (critical > warning > none)
title_color() {
  local c1="$1" c2="$2"
  [ "$c1" = "#FF0000" ] || [ "$c2" = "#FF0000" ] && echo "#FF0000" && return
  [ "$c1" = "#FFD700" ] || [ "$c2" = "#FFD700" ] && echo "#FFD700" && return
  echo ""
}

if [ "$SHOW_7D" = "true" ]; then
  TITLE_COLOR="$(title_color "$COLOR_5H" "$COLOR_7D")"
  TITLE="${PCT_5H}%/${PCT_7D}%"
else
  TITLE_COLOR="$COLOR_5H"
  TITLE="${PCT_5H}%"
fi

# Emit menu bar line
if [ "$SHOW_BARS" = "true" ]; then
  BAR_ICON="$(make_icon "$PCT_5H" "$PCT_7D")"
  echo " | templateImage=${BAR_ICON}"
else
  if [ -n "$TITLE_COLOR" ]; then
    echo "${TITLE} | templateImage=${CLAUDE_ICON} color=${TITLE_COLOR}"
  else
    echo "${TITLE} | templateImage=${CLAUDE_ICON}"
  fi
fi

# === Dropdown ===

echo "---"

# --- 5h window ---
BAR_5H="$(make_bar "$PCT_5H")"
if [ -n "$COLOR_5H" ]; then
  echo "5h window | color=#888888"
  echo "5h: ${PCT_5H}% ${BAR_5H} | color=${COLOR_5H}"
else
  echo "5h window | color=#888888"
  echo "5h: ${PCT_5H}% ${BAR_5H}"
fi

if [ "$SHOW_RESET" = "true" ] && [ -n "$RESET_5H" ]; then
  UNTIL_5H="$(time_until "$RESET_5H")"
  echo "Resets in: ${UNTIL_5H} | color=#888888"
fi

echo "---"

# --- 7d window ---
COLOR_7D_VAL="$(color_for_pct "$PCT_7D")"
BAR_7D="$(make_bar "$PCT_7D")"
echo "7d window | color=#888888"
if [ -n "$COLOR_7D_VAL" ]; then
  echo "7d: ${PCT_7D}% ${BAR_7D} | color=${COLOR_7D_VAL}"
else
  echo "7d: ${PCT_7D}% ${BAR_7D}"
fi

if [ "$SHOW_PACE" = "true" ] && [ -n "$RESET_7D" ]; then
  PCT_PACE_7D="$(pace_pct "$RESET_7D" 7)"
  BAR_PACE_7D="$(make_bar "$PCT_PACE_7D")"
  echo "Pace: ${PCT_PACE_7D}% ${BAR_PACE_7D} | color=#888888"
fi

if [ "$SHOW_RESET" = "true" ] && [ -n "$RESET_7D" ]; then
  UNTIL_7D="$(time_until "$RESET_7D")"
  echo "Resets in: ${UNTIL_7D} | color=#888888"
fi

echo "---"

echo "View usage on Claude.ai | href=https://claude.ai/settings/usage"
echo "Anthropic status | href=https://status.anthropic.com/"
echo "Refresh | refresh=true"
