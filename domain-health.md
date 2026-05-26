# Domain Health
### Cold Email Domain Blacklist Checker · v1.4.0 · revsculpt.com

---

## Overview

Domain Health checks sending domains against 144 email blacklists that control inbox placement, and validates the four DNS authentication records (MX, SPF, DKIM, DMARC) that control whether email is trusted in the first place. Paste a domain — the skill queries a blocklist API covering 144 lists in one request, runs auth checks in parallel, and returns a full health report: what's listed, what's misconfigured, how serious each finding is, and exactly where to go to fix it.

No Puppeteer. No browser. Pure HTTP — blocklist API for blacklist checks, Google DNS-over-HTTPS for authentication records.

---

## Activation

Run this skill whenever the user:

- Pastes a domain or list of domains and asks if they are blacklisted
- Asks about domain reputation, blocklist status, or blacklist checks
- Wants to verify a sending domain before launching a campaign
- Asks about SPF, DKIM, DMARC, or MX setup on a domain
- Provides a CSV file path for bulk domain checking
- Uses any of: "check my domain", "is this domain blacklisted", "domain health", "blacklist check", "is this domain clean", "why are my emails going to spam", "check my SPF", "check my DMARC", "bulk check", "check these domains"

---

## What the Skill Checks

### Blocklists — 144 lists

Blacklist results come from a third-party blocklist API that checks 144 lists and returns each result with an `importance` field (`high`, `medium`, `low`) and a `status` field (`listed`, `clear`, `unchecked`, `timeout`, `inactive`).

One API call is made per domain — a domain-based lookup that checks domain lists (DBL, URIBL, SURBL, and all other domain-reputation lists).

**Statuses:**
- `listed` — the domain appears on this blocklist
- `clear` — checked and not listed
- `unchecked` — the list was not applicable to this lookup type
- `timeout` — the list did not respond in time — report as UNKNOWN
- `inactive` — the list is no longer operating — skip in the report

**Notable lists included:** Spamhaus (SBL, DBL, XBL, PBL, ZEN), Barracuda, SpamCop, Abusix (7 zones), Mailspike, UCEProtect (L1, L2, L3), SpamRATS, PSBL, SURBL, URIBL (black, grey, multi, red), SORBS, GBUdb, NordSpam, Polspam (9 zones), SpameatingMonkey (8 zones), MSRBL (5 zones), 0spam (4 zones), and 80+ more.

---

## Authentication Records

These records determine whether receiving mail servers trust your email before content is ever evaluated. A domain that is clean on every blacklist but missing DMARC will still be rejected or junked by many modern receivers. Check all four.

### MX (Mail Exchange)

Checked via MX record query on the root domain. MX records identify which servers handle inbound mail for the domain. For cold email senders this matters because: if a domain has no MX record, it cannot receive replies — a major trust signal for spam filters. Identify the provider from the MX hostname.

| MX pattern | Provider |
|---|---|
| `*.google.com` / `googlemail.com` | Google Workspace |
| `*.outlook.com` / `*.protection.outlook.com` | Microsoft 365 |
| `*.zoho.com` | Zoho Mail |
| `*.protonmail.ch` | Proton Mail |
| `*.messagingengine.com` | Fastmail |
| No MX record | Domain cannot receive replies — flag this |

### SPF (Sender Policy Framework)

Checked via TXT record on the root domain. Look for `v=spf1`. Parse and report all of the following:

**Policy qualifier (`all` mechanism):**

| Qualifier | What it means |
|---|---|
| `-all` | Strict. Only listed servers may send. Optimal for cold email. |
| `~all` | Soft fail. Unlisted servers accepted but flagged. Acceptable. |
| `?all` | Neutral. No enforcement. Weak — upgrade to `~all` or `-all`. |
| `+all` | Pass all. Any server may send. Dangerous — fix immediately. |
| Missing | No SPF record at all. Email treated as unauthenticated. |

**Multiple SPF records:** Only one SPF TXT record is allowed per domain. If two or more `v=spf1` records exist, the result is a permanent error (permfail) — both records are ignored. Flag this as critical.

**DNS lookup count:** SPF has a hard limit of 10 DNS lookups. Each `include:`, `a`, `mx`, `ptr`, `exists`, and `redirect=` mechanism consumes one lookup. Count all of them in the record and report:
- 1–7: Safe
- 8–9: At risk — one more sender added will break SPF
- 10+: Over limit — SPF will permfail for some receivers

### DMARC (Domain-based Message Authentication)

Checked via TXT record on `_dmarc.DOMAIN`. Look for `v=DMARC1`. Parse and report all significant fields:

**Policy (`p=`):**

| Value | What it means |
|---|---|
| `reject` | Full enforcement. Unauthenticated mail is rejected. Best for cold email. |
| `quarantine` | Partial enforcement. Unauthenticated mail goes to spam. Acceptable. |
| `none` | Monitoring only. No enforcement — upgrade this. |
| Missing | No DMARC record. Domain is unprotected. |

**Enforcement percentage (`pct=`):** Defaults to 100 if absent. If set below 100 (e.g. `pct=10`), enforcement only applies to that percentage of mail — the rest bypasses the policy. Flag any value below 100 as partial enforcement.

**Aggregate reporting (`rua=`):** If absent, the domain owner receives zero visibility into authentication failures, spoofing attempts, or misconfigured senders. Flag missing `rua=` as a significant gap — they are flying blind.

**Failure reporting (`ruf=`):** Optional. Provides per-message failure reports. Note if present.

**Subdomain policy (`sp=`):** If absent, subdomains inherit the root `p=` value. If explicitly set, report it. A common misconfiguration is `p=reject` with `sp=none` — protecting the root while leaving subdomains open.

**Alignment (`adkim=`, `aspf=`):** `r` = relaxed (default, broader match), `s` = strict (exact domain match required). Relaxed is fine for most cold email setups.

### DKIM (DomainKeys Identified Mail)

Checked via TXT record on `SELECTOR._domainkey.DOMAIN`. Probe these 10 selectors — all cold-email-relevant, all run simultaneously as threads:

| Selector | Likely provider |
|---|---|
| `google` | Google Workspace |
| `selector1` | Microsoft 365 |
| `selector2` | Microsoft 365 (secondary) |
| `pm` | Proton Mail |
| `mail` | Generic SMTP / various providers |
| `smtp` | Generic SMTP |
| `default` | Generic |
| `dkim` | Generic |
| `s1` | Generic / SendGrid infrastructure |
| `s2` | Generic / SendGrid infrastructure |

When a DKIM record is found, also check the key type and report whether the public key (`p=`) is present and non-empty. An empty `p=` means the key has been revoked.

If none of the 15 selectors return a valid DKIM record, report DKIM as NOT DETECTED — never as MISSING. The selector may be custom. Direct the user to check their sending platform's DNS setup guide for the correct selector, then verify at mxtoolbox.com/dkim.aspx.

---

## How to Run the Checks

Use the Bash tool for all HTTP requests. Do not attempt to answer from memory or training data. Run the actual curl commands and parse the real responses.

### Step 1 — Call the blocklist API

One call per domain — domain-based lookup only. Run in parallel with authentication checks.

The API accepts a URL-encoded JSON input with a `lookup` key set to the domain. Each response is a JSON object. Extract `result.data.json.blocklists` — an array of objects with `shortName`, `organisation`, `importance`, and `results[].status`.

### Step 2 — Check MX, SPF, DMARC, and DKIM

Run everything in a single Python script using `concurrent.futures.ThreadPoolExecutor`. All requests — the blocklist API call, MX, SPF, DMARC, and all DKIM selector probes — submit simultaneously as threads. No temp files. No shell process spawning. Total wall time is bounded by the slowest single response.

**DKIM selectors (10):** `google`, `selector1`, `selector2`, `pm`, `mail`, `smtp`, `default`, `dkim`, `s1`, `s2`. These cover Google Workspace, Microsoft 365, Proton Mail, Amazon SES, and generic SMTP setups — the full range of cold email infrastructure. Zoho, Fastmail, and other platform-specific selectors removed.

### Step 3 — Full script

Run this as a Python heredoc via Bash, substituting the domain:

```bash
python3 << 'PYEOF'
import subprocess, urllib.parse, json, re
import concurrent.futures

DOMAIN = "USER_DOMAIN_HERE"

def fetch_json(url, timeout=10):
    try:
        result = subprocess.run(
            ['curl', '-s', '--max-time', str(timeout), url],
            capture_output=True, text=True, timeout=timeout + 3
        )
        return json.loads(result.stdout)
    except Exception:
        return {}

def google_dns(name, rtype):
    return fetch_json(f"https://dns.google/resolve?name={name}&type={rtype}")

def fetch_bl(lookup):
    enc = urllib.parse.quote(json.dumps({'json': {'lookup': lookup}}))
    return fetch_json(
        f"https://www.suped.com/api/trpc/blocklists.getBlocklists?input={enc}",
        timeout=15
    )

DKIM_SELECTORS = ['google','selector1','selector2','pm','mail','smtp','default','dkim','s1','s2']

with concurrent.futures.ThreadPoolExecutor(max_workers=15) as ex:
    # Submit everything simultaneously
    f_domain_bl = ex.submit(fetch_bl, DOMAIN)
    f_mx        = ex.submit(google_dns, DOMAIN, "MX")
    f_spf       = ex.submit(google_dns, DOMAIN, "TXT")
    f_dmarc     = ex.submit(google_dns, f"_dmarc.{DOMAIN}", "TXT")
    f_dkim      = {sel: ex.submit(google_dns, f"{sel}._domainkey.{DOMAIN}", "TXT")
                   for sel in DKIM_SELECTORS}

    # Collect everything
    domain_bl_resp = f_domain_bl.result()
    mx_data        = f_mx.result()
    spf_data       = f_spf.result()
    dmarc_data     = f_dmarc.result()
    dkim_results   = {sel: f.result() for sel, f in f_dkim.items()}

# ── Parse blocklists ──────────────────────────────────────────
def extract_bl(resp):
    try:
        return resp['result']['data']['json']['blocklists']
    except Exception:
        return []

merged = {}
for bl in extract_bl(domain_bl_resp):
    key  = bl['shortName']
    st   = bl['results'][0]['status'] if bl['results'] else 'unchecked'
    imp  = bl['importance']
    org  = bl['organisation']
    if st != 'inactive':
        merged[key] = {'status': st, 'importance': imp, 'organisation': org}

listed   = [(k,v) for k,v in merged.items() if v['status']=='listed']
timeouts = [(k,v) for k,v in merged.items() if v['status']=='timeout']
clear    = [(k,v) for k,v in merged.items() if v['status']=='clear']

print(f"LISTED_COUNT:{len(listed)}")
print(f"CLEAR_COUNT:{len(clear)}")
print(f"TIMEOUT_COUNT:{len(timeouts)}")
print(f"TOTAL_CHECKED:{len(listed)+len(clear)+len(timeouts)}")
for name, v in listed:
    print(f"LISTED|{name}|{v['organisation']}|{v['importance']}")
for name, v in timeouts:
    print(f"TIMEOUT|{name}|{v['organisation']}|{v['importance']}")

# ── MX ────────────────────────────────────────────────────────
try:
    records = [r['data'].split()[-1].rstrip('.')
               for r in mx_data.get('Answer', []) if r.get('type') == 15]
    if records: print(f"AUTH|MX|FOUND|{','.join(records[:2])}")
    else: print("AUTH|MX|MISSING|")
except: print("AUTH|MX|UNKNOWN|")

# ── SPF ───────────────────────────────────────────────────────
try:
    spf = [r.get('data','').strip('"') for r in spf_data.get('Answer', [])
           if r.get('data','').strip('"').startswith('v=spf1')]
    if not spf:
        print("AUTH|SPF|MISSING||0|")
    elif len(spf) > 1:
        print("AUTH|SPF|MULTIPLE||0|")
    else:
        rec = spf[0]
        q = ('strict'   if '-all' in rec else
             'softfail' if '~all' in rec else
             'passall'  if '+all' in rec else
             'neutral'  if '?all' in rec else 'none')
        n = len(re.findall(r'\binclude:|\bredirect=|\b(?:a|mx|ptr|exists)(?::|$| )', rec))
        print(f"AUTH|SPF|FOUND|{q}|{n}|{rec}")
except: print("AUTH|SPF|UNKNOWN||0|")

# ── DMARC ─────────────────────────────────────────────────────
try:
    found_dmarc = False
    for r in dmarc_data.get('Answer', []):
        data = r.get('data', '').strip('"')
        if data.startswith('v=DMARC1'):
            def g(t): m = re.search(rf'{t}=([^;]+)', data); return m.group(1).strip() if m else ''
            print(f"AUTH|DMARC|FOUND|{g('p')}|{g('pct') or '100'}|{g('rua')}|{g('ruf')}|{g('sp')}|{g('adkim') or 'r'}|{g('aspf') or 'r'}")
            found_dmarc = True; break
    if not found_dmarc: print("AUTH|DMARC|MISSING|||||||")
except: print("AUTH|DMARC|UNKNOWN|||||||")

# ── DKIM — first hit in selector priority order ───────────────
found_dkim = False
for sel in DKIM_SELECTORS:
    d = dkim_results.get(sel, {})
    for r in d.get('Answer', []):
        data = r.get('data', '').strip('"')
        if 'v=DKIM1' in data or 'p=' in data:
            m = re.search(r'p=([^;\ ]+)', data)
            st = 'active' if (m and m.group(1)) else 'revoked'
            print(f"AUTH|DKIM|FOUND|{sel}|{st}")
            found_dkim = True; break
    if found_dkim: break
if not found_dkim: print("AUTH|DKIM|NOT_DETECTED||")
PYEOF
```

Parse the output: `LISTED|name|org|importance` lines drive the report and scoring. `TIMEOUT` lines are reported as UNKNOWN. `AUTH|` lines feed the authentication section.

**Expected timing per domain:** 2–5 seconds. All requests run as threads simultaneously — no shell process spawning, no temp file I/O. Wall time is bounded by the blocklist API response (~2-4s).

---

## Scoring

Calculate a Domain Health Score based on the API's `importance` field values:

```
Starting score: 100

importance: high   listing → −25 pts each
importance: medium listing → −10 pts each
importance: low    listing →  −5 pts each

Minimum: 0
```

| Score | Status |
|---|---|
| 90–100 | CLEAN — safe to send |
| 70–89 | CAUTION — monitor closely |
| 50–69 | AT RISK — deliverability affected |
| 0–49 | CRITICAL — immediate action needed |

---

## Removal Links

Include these in the report whenever a domain or IP is listed:

| List | Removal URL |
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

## Output Template

### Single domain report

```
[ DOMAIN HEALTH ]  domain-checked.com

SCORE
  Domain Health   [score]/100   [CLEAN / CAUTION / AT RISK / CRITICAL]
  Checked         [n] blocklists   [x] listed · [y] clean
  Completed       [timestamp]

LISTED — ACTION NEEDED

  [List Name]  [HIGH / MEDIUM]
  Your [domain / sending IP] appears on this list.
  What it means:   [one plain sentence on what this affects]
  Remove here:     [removal URL]

CLEAN LISTS

  HIGH IMPACT    [n]/[total] clean
  MEDIUM IMPACT  [n]/[total] clean

AUTHENTICATION

  MX      [CONFIGURED / MISSING]   [provider name — Google Workspace / Microsoft 365 / etc.]
          [If missing: "No MX record found. This domain cannot receive replies — spam
           filters treat no-MX domains as suspicious."]

  SPF     [CONFIGURED / MULTIPLE RECORDS / MISSING]
          Policy:   [Strict (-all) / Soft fail (~all) / Neutral (?all) / Pass all (+all) / None]
          Lookups:  [n]/10   [Safe / At risk / Over limit]
          [If multiple records: "Two SPF records found — this causes a permanent error.
           Merge into one record."]
          [If +all: "SPF set to pass all — any server can send as your domain. Fix immediately."]
          [If lookup count ≥ 8: "Approaching the 10-lookup limit. Adding more senders
           will break SPF."]

  DMARC   [CONFIGURED / MISSING]
          Policy:      [reject / quarantine / none]
          Enforcement: [pct value]% of mail   [Full / Partial — note if below 100]
          Reporting:   [rua address if present / "No reporting configured — blind to failures"]
          Subdomain:   [sp= value if set / "Inherits root policy"]
          [If p=none: "Monitoring only — no mail is blocked. Upgrade to quarantine."]
          [If rua missing: "No aggregate reporting address. You have no visibility into
           authentication failures or spoofing attempts."]

  DKIM    [CONFIGURED / NOT DETECTED]
          [If found: "Selector: [selector] — likely [provider]. Key: active."]
          [If found but revoked: "Selector: [selector] found but key is revoked (p= is empty).
           Regenerate the DKIM key in your sending platform."]
          [If not detected: "Not found on 15 common selectors. Your sending platform may use
           a custom selector. Check your platform's DNS setup guide, then verify at
           mxtoolbox.com/dkim.aspx"]

WHAT THIS MEANS FOR YOUR SENDING

  [2–3 plain sentences covering both blacklist results and authentication gaps —
   what the combined picture means for inbox placement, whether campaigns should be
   paused, and the most important next step. Tailored to what was actually found.]

NEXT STEPS

  [Numbered list of specific actions in priority order.
   If listed on HIGH IMPACT blocklist: pause sending, delist first.
   If auth gaps: fix in order MX → SPF → DKIM → DMARC.
   If clean and auth configured: what to watch and how often to recheck.]

  revsculpt.com
```

### Batch report (multiple domains)

When checking multiple domains, output a summary table first, then full individual reports for any domain that has issues.

```
[ DOMAIN HEALTH ]  Batch check · [n] domains · [timestamp]

SUMMARY

  Domain                  Score    Blacklists    SPF        DMARC      DKIM
  ─────────────────────────────────────────────────────────────────────────────
  domain1.com             98/100   All clean     Strict     reject     google
  domain2.com             60/100   1 listed      Soft fail  none       selector1
  domain3.com             100/100  All clean     Strict     reject     Not found
  domain4.com             0/100    3 listed      MISSING    MISSING    Not found

DOMAINS NEEDING ACTION

  [Full individual report for each domain with score below 90 or any auth gap]

  revsculpt.com
```

---

## Batch and CSV Mode

### Under 100 domains — paste in chat

If the user pastes a list of domains directly in the message (one per line, or comma-separated), detect this automatically and run checks on each domain sequentially. Output the summary table first, then full reports for any domain that needs action.

### 100+ domains — CSV file

If the user provides a file path to a CSV, use the Read tool to load the file. Detect the column that contains domains by checking column headers for: `domain`, `sending domain`, `website`, `url`, `email domain`. If no header matches, use the first column. Strip any protocol prefixes (`https://`, `http://`, `www.`) before checking.

Run checks on each domain sequentially — do not attempt to parallelize across domains, only within each individual domain check. Output the summary table as each domain completes, then full individual reports for domains needing action at the end.

**CSV processing logic:**

```python
# Read the CSV, find the domain column, extract clean domains
import csv, re

def extract_domain(value):
    value = value.strip().lower()
    value = re.sub(r'^https?://', '', value)
    value = re.sub(r'^www\.', '', value)
    value = value.split('/')[0]
    return value
```

**Progress output during CSV processing:**

After each domain completes, print one line:
```
  [n/total]  domain.com  →  [score]/100  [n listed / all clean]
```

This lets the user see progress without waiting for the entire batch.

**Rate limiting awareness for bulk checks:**

The blocklist API has no documented rate limit, but aggressive use may result in throttling. If any API call returns a non-JSON response or an error, retry once, then mark all lists for that domain as UNKNOWN and continue to the next. Note the failure count at the end of the batch report.

---

## Hard Rules

- Always run the actual curl commands — never guess or estimate blacklist status or authentication records
- If the blocklist API returns a non-JSON or error response, retry once, then mark all blocklists for that domain as UNKNOWN
- Never mark a domain as CLEAN if any `importance: high` list returned `listed`
- Include removal links for every listing — never just flag without giving the path to fix it
- Skip `inactive` lists entirely — do not show them in the report
- Report `timeout` results as UNKNOWN — not clean, not listed
- If DKIM is not detected on any of the 15 selectors, report NOT DETECTED — never MISSING (selector may be custom)
- Always run authentication checks alongside blocklist checks — never skip the auth section
- Never report SPF as CONFIGURED if two or more SPF TXT records exist — that is a permfail condition
- Never report DMARC enforcement as full if `pct=` is below 100
- Always flag missing `rua=` in DMARC as a gap — the domain owner has no visibility into authentication failures
- In CSV/batch mode: process domains sequentially, print progress after each one, note API failures at the end
