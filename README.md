# Domain Health — Cold Email Domain Blacklist & Auth Checker

[![License](https://img.shields.io/badge/license-Proprietary-black?style=flat-square)](./LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-orange?style=flat-square)](https://claude.ai/code)
[![Built by RevSculpt](https://img.shields.io/badge/by-RevSculpt-0a0a0a?style=flat-square)](https://revsculpt.com)

*Built by [RevSculpt](https://revsculpt.com) — the B2B revenue systems team behind 6,000+ qualified meetings booked.*

---

Your emails aren't bouncing. They're not erroring. They're just disappearing.

Most senders never check whether their domain is on a blacklist until something breaks. By then, the damage is already done — campaigns sent, replies missed, domain reputation burned.

Domain Health checks your sending domain against **144 blocklists** and validates your **MX, SPF, DKIM, and DMARC** records. Paste a domain, get a full health report in seconds.

**Domain Health is built as a [Claude Code](https://claude.ai/code) skill.** No dashboard. No account. No browser tab.

---

## What It Checks

### 144 Blocklists

Blacklist data comes from a third-party blocklist API — 144 active lists checked in one HTTP request. Results are scored by impact level: high, medium, and low.

```
HIGH IMPACT
  Spamhaus (SBL, DBL, XBL, PBL, ZEN)    Most authoritative globally. Used by the majority of mail servers.
  Barracuda                               Standard in enterprise environments.
  SpamCop                                 Automated complaint-based. Fast to list, auto-expires.
  Abusix (7 zones)                        Combines multiple abuse feeds. Used by many ESPs.
  Mailspike                               Reputation-based. High-volume receivers.
  UCEProtect L1                           Single-IP listings. Widely consulted.
  SpamRATS                                Dynamic IPs and spam sources.
  PSBL                                    Conservative. Passive spam block list.
  URIBL Black                             High-confidence domain blacklist. Very serious listing.
  SURBL                                   Combines multiple URI reputation feeds.

MEDIUM IMPACT
  SORBS                                   Aggregate of spam and abuse sources.
  UCEProtect L2 / L3                      Network-level. Can affect clean IPs by association.
  GBUdb                                   Statistical spam tracking.
  NordSpam (IP + Domain)                  Increasingly adopted globally.
  URIBL Grey                              Domains seen in spam but not confirmed. Monitor closely.
  Polspam (9 zones)                       Regional but widely checked.
  SpameatingMonkey (8 zones)
  MSRBL (5 zones)
  0spam (4 zones)
  + 80 more active lists
```

### Authentication Records

Clean blacklists are not enough. A domain that passes every list but has no DMARC will still be junked by modern receivers. Domain Health checks all four:

```
MX     — Is there a mail exchange record? Which provider?
SPF    — Is a policy set? Strict, soft fail, or dangerous? How many DNS lookups?
DKIM   — Is a signing key present? Probes 15 cold-email selectors.
DMARC  — What policy is enforced? Full or partial? Is reporting configured?
```

---

## What a Check Looks Like

```
[ DOMAIN HEALTH ]  yourdomain.com

SCORE
  Domain Health   87/100   CAUTION
  Checked         144 blocklists   1 listed · 138 clean · 5 unknown
  Completed       2026-05-25 14:32 UTC

LISTED — ACTION NEEDED

  UCEProtect L1  HIGH
  Your sending IP appears on this list.
  What it means:   Single-IP listing that causes mail servers to reject or
                   defer your outbound email at the connection stage.
  Remove here:     https://www.uceprotect.net/en/rblcheck.php

CLEAN LISTS

  HIGH IMPACT    18/19 clean
  MEDIUM IMPACT  120/125 clean

AUTHENTICATION

  MX      CONFIGURED   Google Workspace

  SPF     CONFIGURED
          Policy:   Strict (-all)
          Lookups:  6/10   Safe

  DMARC   CONFIGURED
          Policy:      quarantine
          Enforcement: 100% of mail
          Reporting:   reports@yourdomain.com
          Subdomain:   Inherits root policy

  DKIM    CONFIGURED
          Selector: google — likely Google Workspace. Key: active.

WHAT THIS MEANS FOR YOUR SENDING

  One high-impact listing on UCEProtect L1. Auth records are fully
  configured — SPF strict, DMARC at quarantine, DKIM active. The
  listing is the only blocker. Submit removal before your next campaign.

NEXT STEPS

  1. Submit removal at uceprotect.net — self-service, usually resolves in 24h
  2. Recheck in 48 hours to confirm delisting
  3. Upgrade DMARC from quarantine to reject once sending is stable

  revsculpt.com
```

---

## How It Works

```
NO BROWSER. NO PUPPETEER. PURE HTTP.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Step 1 — Calls blocklist API (domain lookup) — 144 lists, 1 request
  Step 2 — Runs MX, SPF, DMARC, and DKIM checks in parallel
  Step 3 — Scores by importance, identifies auth gaps
  Step 4 — Returns a full health report with removal links and next steps

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Blocklist check completes in 1 HTTP request instead of 144 DNS queries.
  All requests run simultaneously via Python ThreadPoolExecutor — no temp files,
  no shell process spawning, true in-process concurrency.
  Every request is capped so stalled servers cannot block the check.
  A full check typically completes in under 4 seconds per domain.
```

---

## Scoring

```
Starting score: 100

importance: high   listing → -25 pts each
importance: medium listing → -10 pts each
importance: low    listing →  -5 pts each

Minimum: 0
```

| Score | Status |
|---|---|
| 90-100 | CLEAN — safe to send |
| 70-89 | CAUTION — monitor closely |
| 50-69 | AT RISK — deliverability affected |
| 0-49 | CRITICAL — immediate action needed |

---

## Batch and CSV Mode

### Under 100 domains — paste in chat

Paste a list of domains (one per line or comma-separated). The skill checks each one sequentially and outputs a summary table, then full reports for any domain needing action.

### 100+ domains — CSV file

Provide a file path to a CSV. The skill reads it, finds the domain column automatically, and processes each domain in sequence. Progress is printed after each domain completes:

```
  [1/200]  domain1.com  →  98/100  all clean
  [2/200]  domain2.com  →  60/100  1 listed
  [3/200]  domain3.com  →  100/100  all clean
  ...
```

Full reports for domains needing action appear at the end.

---

## Good to Know

**Starting a check**

Type `/domain-health` and paste a domain. Or say "check my domain", "is this domain blacklisted", or "check my DMARC" anywhere in Claude Code — the hook fires automatically.

**What you need**

Just a domain. The skill runs all checks directly from the domain name.

**Multiple domains**

Paste multiple domains in one message. Each gets its own labeled report, plus a summary table at the top.

**If a list is unavailable**

Timeouts are marked UNKNOWN, not CLEAN. You always know when a result is missing.

**If DKIM is not detected**

The skill probes 15 cold-email selectors. If none return a record, it reports NOT DETECTED — never MISSING. Your platform may use a custom selector. Check your sending platform's DNS setup guide, then verify at mxtoolbox.com/dkim.aspx.

**How often to check**

During active sending: weekly. Before a new campaign: always. If inbox rates drop unexpectedly: immediately.

---

## Removal Links

If your domain or IP appears on a list, these are the direct paths to request removal:

| List | Removal |
|---|---|
| Spamhaus ZEN / DBL | https://www.spamhaus.org/lookup/ |
| Barracuda | https://www.barracudacentral.org/rbl/removal-request |
| SpamCop | https://www.spamcop.net/bl.shtml |
| Abusix | https://lookup.abusix.com |
| UCEProtect | https://www.uceprotect.net/en/rblcheck.php |
| SORBS | http://www.sorbs.net/lookup.shtml |
| URIBL | https://admin.uribl.com/?section=lookup |
| SURBL | https://www.surbl.org/surbl-analysis |
| Mailspike | https://www.mailspike.net/usage.html |
| SpamRATS | https://www.spamrats.com/removal.php |
| PSBL | https://psbl.surriel.com/ |

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/George-RevSculpt/Domain-Health/main/install.sh | bash
```

Open [Claude Code](https://claude.ai/code) in any directory and run:

```
/domain-health
```

Paste a domain. Get a full blacklist and authentication report.

Already installed? Re-run the same command to update to the latest version.

---

## Files

| File | Purpose |
|---|---|
| `domain-health.md` | The Claude Code skill — installs to `~/.claude/skills/` |
| `install.sh` | One-command installer |
| `.claude/hooks/domain-health-active.sh` | Hook script — fires on relevant prompts |

---

## Requirements

- [Claude Code](https://claude.ai/code) — the CLI for Claude
- An [Anthropic](https://anthropic.com) account
- macOS, Linux, or Windows (WSL)
- `curl` or `wget`
- `python3` (pre-installed on macOS and most Linux distros)

---

**Built by**

[**RevSculpt**](https://revsculpt.com) — B2B Revenue Systems · Signal-Timed Outreach · AI-Powered Enrichment · Full Pipeline Infrastructure

*18 days to first qualified meeting. 6,000+ qualified meetings booked. 14x ROI on outbound spend.*

*Written and maintained by [RevSculpt](https://github.com/George-RevSculpt)*

© 2026 RevSculpt™. All rights reserved. — [License](./LICENSE)

---

v1.4.0
