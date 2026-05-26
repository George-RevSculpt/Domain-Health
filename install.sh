#!/bin/bash
# Domain Health — v1.0.0
# revsculpt.com

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
RELEASE_URL="https://raw.githubusercontent.com/George-RevSculpt/Domain-Health/main"
INSTALL_DIR="$HOME/.claude/skills/domain-health"
HOOK_DIR="$HOME/.claude/hooks"
CONFIG_PATH="$HOME/.claude/settings.json"
TOOL_VERSION="1.0.0"

# ── Terminal colors ───────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
W='\033[1;37m'
D='\033[2m'
B='\033[1m'
N='\033[0m'

# ── Step counter ──────────────────────────────────────────────
STEP=0
step() {
  STEP=$((STEP + 1))
  printf "\n  ${D}[${STEP}]${N} ${W}${1}${N}\n"
}

ok()   { printf "      ${G}✓${N}  ${D}${1}${N}\n"; }
fail() { printf "      ${R}✗${N}  ${1}\n"; exit 1; }

# ── Fetch helper ──────────────────────────────────────────────
fetch() {
  local src="$1" dest="$2"
  if command -v curl &>/dev/null; then
    curl -fsSL --proto '=https' --max-redirs 3 "$src" -o "$dest" || fail "Download failed: $src"
  elif command -v wget &>/dev/null; then
    wget -q --https-only "$src" -O "$dest" 2>/dev/null || \
    wget -q "$src" -O "$dest" || fail "Download failed: $src"
  else
    fail "curl or wget required — neither found"
  fi
}

# ── Merge hook into settings.json ─────────────────────────────
wire_hook() {
  local hook_cmd="bash '${HOOK_DIR}/domain-health-active.sh'"
  local matcher="blacklist|blocklist|domain health|check my domain|is this domain blacklisted|domain reputation|sending domain|delist|spam filter|why are my emails going to spam|domain check|is this domain clean"

  if command -v python3 &>/dev/null; then
    DH_CFG="$CONFIG_PATH" DH_MATCHER="$matcher" DH_CMD="$hook_cmd" python3 - <<'PYEOF'
import json, os

cfg_path = os.environ['DH_CFG']
matcher  = os.environ['DH_MATCHER']
hook_cmd = os.environ['DH_CMD']

cfg = {}
if os.path.isfile(cfg_path):
    try:
        with open(cfg_path, 'r') as f:
            cfg = json.load(f)
    except (json.JSONDecodeError, OSError):
        cfg = {}

entry = {
    "matcher": matcher,
    "hooks": [{"type": "command", "command": hook_cmd}]
}

cfg.setdefault('hooks', {}).setdefault('UserPromptSubmit', [])

if not any(h.get('matcher') == entry['matcher'] for h in cfg['hooks']['UserPromptSubmit']):
    cfg['hooks']['UserPromptSubmit'].append(entry)

with open(cfg_path, 'w') as f:
    json.dump(cfg, f, indent=2)
PYEOF
  else
    mkdir -p "$(dirname "$CONFIG_PATH")"
    printf '%s\n' '{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "blacklist|blocklist|domain health|check my domain|domain reputation|sending domain",
        "hooks": [
          {"type": "command", "command": "bash '"'"'${HOOK_DIR}/domain-health-active.sh'"'"'"}
        ]
      }
    ]
  }
}' > "$CONFIG_PATH"
  fi
}

# ─────────────────────────────────────────────────────────────
clear

printf "\n"
printf "${W}"
printf "  ██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗    ██╗  ██╗███████╗ █████╗ ██╗  ████████╗██╗  ██╗\n"
printf "  ██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║    ██║  ██║██╔════╝██╔══██╗██║  ╚══██╔══╝██║  ██║\n"
printf "  ██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║    ███████║█████╗  ███████║██║     ██║   ███████║\n"
printf "  ██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║    ██╔══██║██╔══╝  ██╔══██║██║     ██║   ██╔══██║\n"
printf "  ██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║    ██║  ██║███████╗██║  ██║███████╗██║   ██║  ██║\n"
printf "  ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝\n"
printf "${N}\n"
printf "  ${D}Cold Email Domain Blacklist Checker · v${TOOL_VERSION} · revsculpt.com${N}\n"
printf "\n  ${D}$(printf '─%.0s' {1..72})${N}\n"
sleep 0.5

# ── Preflight ─────────────────────────────────────────────────
step "Checking environment"

command -v claude &>/dev/null || fail "Claude Code not found. Install it at https://claude.ai/code"
ok "Claude Code detected"

{ command -v curl &>/dev/null || command -v wget &>/dev/null; } || fail "curl or wget required"
ok "Download tool available"

command -v python3 &>/dev/null && ok "Python 3 available" || ok "Python 3 not found — using fallback config writer"

# ── Directories ───────────────────────────────────────────────
step "Creating directories"
mkdir -p "$INSTALL_DIR" "$HOOK_DIR"
ok "$INSTALL_DIR"
ok "$HOOK_DIR"

# ── Files ─────────────────────────────────────────────────────
step "Downloading skill files"

fetch "$RELEASE_URL/domain-health.md"  "$INSTALL_DIR/SKILL.md"
ok "SKILL.md  (144-list domain blacklist checker)"

fetch "$RELEASE_URL/.claude/hooks/domain-health-active.sh" "$HOOK_DIR/domain-health-active.sh"
chmod +x "$HOOK_DIR/domain-health-active.sh"
ok "domain-health-active.sh  (smart activation hook)"

# ── Hook wiring ───────────────────────────────────────────────
step "Wiring activation hook"
wire_hook
ok "Hook registered in $CONFIG_PATH"
ok "Fires only on domain/blacklist-related prompts"

# ── Done ──────────────────────────────────────────────────────
printf "\n  ${D}$(printf '─%.0s' {1..72})${N}\n\n"
printf "  ${W}${B}Installed successfully.${N}\n\n"

printf "  ${W}Usage${N}\n"
printf "  ${D}Open Claude Code and type:${N}  ${C}/domain-health${N}\n"
printf "  ${D}Paste a domain — get a full blacklist report.${N}\n\n"

printf "  ${W}What gets checked${N}\n"
printf "  ${D}HIGH IMPACT   Spamhaus (SBL, DBL, XBL, PBL, ZEN), Barracuda, SpamCop${N}\n"
printf "  ${D}              Abusix, Mailspike, UCEProtect L1, SpamRATS, PSBL${N}\n"
printf "  ${D}              URIBL Black, SURBL, and 130+ more${N}\n"
printf "  ${D}MEDIUM IMPACT SORBS, UCEProtect L2/L3, GBUdb, NordSpam${N}\n"
printf "  ${D}              URIBL Grey, Polspam, SpameatingMonkey, MSRBL${N}\n\n"

printf "  ${W}How it works${N}\n"
printf "  ${D}No Puppeteer. No browser. Pure HTTP.${N}\n"
printf "  ${D}Checks 144 blocklists in one API call, runs MX/SPF/DKIM/DMARC${N}\n"
printf "  ${D}checks in parallel, returns a scored report with removal links.${N}\n\n"

printf "  ${W}Score${N}\n"
printf "  ${D}90-100  CLEAN — safe to send${N}\n"
printf "  ${D}70-89   CAUTION — monitor closely${N}\n"
printf "  ${D}50-69   AT RISK — deliverability affected${N}\n"
printf "  ${D}0-49    CRITICAL — immediate action needed${N}\n\n"

printf "  ${D}Built by RevSculpt — revsculpt.com${N}\n\n"
