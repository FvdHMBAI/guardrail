# Gumroad Listing: GuardRail Pro

## Produktname
GuardRail Pro

## Untertitel
Advanced security guards for AI coding agents. Script analysis, multi-step attack detection, EU AI Act compliance.

## Preis
29 EUR/dev/Monat

## Beschreibung

### Your AI agent runs commands on your machine. GuardRail makes sure the dangerous ones never execute.

The free version gives you 18 battle-tested guards. GuardRail Pro adds the guards that catch what regex cannot.

### What's in Pro

**Script Content Analysis**
Your agent writes `payload.sh`, then runs `bash payload.sh`. Command-line guards see "bash payload.sh" and let it through. Pro reads the script content before execution and blocks the payload inside.

**Multi-Step Attack Detection**
Step 1: Agent scans for credentials. Step 2: Agent exfiltrates via curl. Each step looks harmless alone. Pro tracks sequences and blocks on step 2.

**PII Shield v2**
ML-powered detection of personal data in command output. Social security numbers, tax IDs, home addresses, phone numbers. Goes beyond regex patterns.

**Supply Chain Audit**
Before `npm install` runs, Pro checks the package against known vulnerabilities and restrictive licenses. Blocks before the code lands on your machine.

**EU AI Act Compliance Kit**
Guard-to-article mapping for Art. 9 (risk management), Art. 12 (record-keeping), Art. 14 (human oversight). PDF audit reports your compliance team can hand to regulators.

### Free vs Pro

| | Free (MIT) | Pro |
|---|---|---|
| Core guards | 18 | 18 |
| Script content analysis | - | Ja |
| Multi-step detection | - | Ja |
| PII Shield v2 | - | Ja |
| Supply chain audit | - | Ja |
| EU AI Act reports | - | Ja |
| Penetration test (50+ patterns) | - | Ja |
| Priority support | - | Ja |
| Guard count | 18 | 48+ |

### Who is this for

- Solo developers running AI agents on production servers
- Teams using Claude Code, Cursor, or Copilot with shell access
- Companies that need EU AI Act documentation for their AI tooling
- Anyone who wants to catch problems before they happen, not after

### How it works

1. Install the free version: `npx guardrail-agent init`
2. Purchase a Pro license key
3. Run: `guardrail upgrade --key YOUR_KEY`
4. Pro guards activate immediately. No restart needed.

### Built by a practitioner

GuardRail patterns come from a production system running 169+ guards across 15 applications since 2025. Every guard exists because it prevents a real pattern. 870 blocked commands per week. This is not theory.

---

## Tags
AI, Security, Developer Tools, Claude Code, DevOps, EU AI Act

## Thumbnail-Text
GuardRail Pro: 48 guards. Script analysis. EU AI Act compliance. Für AI coding agents.
