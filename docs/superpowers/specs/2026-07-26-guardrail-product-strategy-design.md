# GuardRail Produktstrategie & Shield-Integration

## Entscheidung

GuardRail ist das Sicherheitssystem fuer KI-Coding-Agenten. Kein Dashboard,
keine Plattform -- ein System das zwischen Agent und Maschine steht und
gefaehrliche Aktionen blockt bevor sie passieren.

DSGVO Shield wird als Guard-Modul in GuardRail integriert. Die bestehende
Shield-API bleibt als "GuardRail PII Shield" live, wird aber nicht separat
vermarktet.

## Positionierung

**Kategorie:** Coding-Agent Security (Pre-Execution Guards)
**Differenzierung:** Einziges Produkt mit Pre-Execution Guards speziell fuer
KI-Coding-Agenten (Claude Code, Cursor, Copilot). Kein Wettbewerber adressiert
diese Nische.
**Beweis:** 104 Guards in Produktion, PEN-Test-verifiziert, Self-Improving,
Sub-Agent-Enforcement das nicht mal Microsoft hat.

## Produktarchitektur

### Bestehendes (fertig, deployed)

| Komponente | Status | Beschreibung |
|-----------|--------|-------------|
| Guard Engine | npm v0.2.3 | Dispatcher, Hook-Verdrahtung, deny()/allow() API |
| 10 Core Guards | MIT, Open Source | main_push, basic_secret, basic_pii, env_dump, etc. |
| 48 Pro Guards | Proprietaer | Advanced Injection, DB-Protection, Deploy-Safety |
| License API | Forma-Server | Express + SQLite + Stripe, Key-Generierung |
| CLI | npm | `npx guardrail-agent init`, `guardrail upgrade --key` |
| Landing Page | Live | guardrail.promptandbuild.de |
| DSGVO Shield API | Forma-Server | Python PII-Scanner, 10 EU-Laender, 3-stufig |

### Neue Module (diese Session)

#### 1. PII Shield Guard

Shell-Guard der Agent-Outputs auf personenbezogene Daten scannt.

**Hook-Typ:** Post-Bash (scannt Command-Output)
**Datei:** `guards/premium/pii_shield_guard.sh`
**Mechanik:**
- Extrahiert die letzten N Zeilen aus dem Bash-Output ($OUTPUT)
- Sendet per curl POST an shield.promptandbuild.de/classify
- API-Key kommt aus der GuardRail-Lizenz (Pro-Kunden haben einen)
- Stufe SICHER -> deny() mit Fundliste
- Stufe PRUEFEN -> allow_with_msg() als Warnung
- Stufe FREI -> durchlassen
- Timeout: 3 Sekunden, bei Timeout durchlassen (kein Blocker fuer den Workflow)
- Max Output-Länge: 5000 Zeichen (truncate, nicht blocken)

**Konfiguration:** `guardrail.config.sh`
- `GUARDRAIL_PII_SHIELD_URL` (default: shield.promptandbuild.de)
- `GUARDRAIL_PII_SHIELD_KEY` (aus .license-key oder eigener Shield-Key)
- `GUARDRAIL_PII_COUNTRIES` (default: "de,at" -- welche Laendermodule)
- `GUARDRAIL_PII_MODE` (default: "warn" -- "warn" oder "block")

#### 2. Audit Trail Guard

Loggt jede Guard-Entscheidung in strukturiertes JSONL.

**Hook-Typ:** Post-Bash + Post-Edit + Pre-Bash (universell)
**Datei:** `guards/premium/audit_trail_guard.sh`
**Mechanik:**
- Schreibt eine JSON-Zeile pro Guard-Aufruf nach `~/.guardrail/audit.jsonl`
- Felder: timestamp (ISO 8601), command (truncated auf 200 Zeichen),
  guard_name, decision (allow/deny/warn), reason, cwd, session_id
- session_id aus `$SESSION_ID` (von Claude Code gesetzt)
- Datei-Rotation: neuer Tag = neue Datei (audit-2026-07-26.jsonl)
- Kein Netzwerk, kein externer Service -- rein lokal

**Konfiguration:**
- `GUARDRAIL_AUDIT_DIR` (default: ~/.guardrail/audit/)
- `GUARDRAIL_AUDIT_RETENTION_DAYS` (default: 90)

#### 3. Compliance Reporter

CLI-Befehl der aus Audit-Logs einen EU-AI-Act-Compliance-Nachweis generiert.

**Befehl:** `guardrail compliance-report`
**Datei:** `bin/compliance-report.sh`
**Mechanik:**
- Liest alle JSONL-Dateien aus `~/.guardrail/audit/`
- Filtert nach Zeitraum (`--from`, `--to`)
- Zaehlt: aktive Guards, Gesamtentscheidungen, Denials, Warnings
- Mappt Guards auf EU-AI-Act-Artikel (Mapping-Tabelle in `lib/eu-ai-act-mapping.sh`)
- Output-Formate: Markdown (default), HTML (`--format html`)
- Sektionen:
  1. Executive Summary (Zeitraum, Guard-Coverage, Compliance-Score)
  2. Guard-Aktivitaet (welche Guards wie oft gefeuert)
  3. Incidents (alle Denials mit Kontext)
  4. EU-AI-Act-Mapping (welcher Artikel durch welche Guards abgedeckt)
  5. Empfehlungen (welche Guards fehlen fuer volle Compliance)

**EU-AI-Act-Artikel-Mapping:**

| Guard-Kategorie | EU AI Act Artikel | Anforderung |
|----------------|------------------|-------------|
| Secret Detection | Art. 15 (Accuracy) | Verhinderung von Credential-Leaks |
| PII Shield | Art. 10 (Data Governance) | Schutz personenbezogener Daten |
| Injection Prevention | Art. 15 (Robustness) | Schutz vor Manipulation |
| DB Protection | Art. 15 (Accuracy) | Verhinderung von Datenverlust |
| Audit Trail | Art. 12 (Record-keeping) | Nachvollziehbarkeit aller Aktionen |
| Deployment Safety | Art. 14 (Human Oversight) | Menschliche Kontrolle bei Deployments |
| Force-Push Guard | Art. 14 (Human Oversight) | Schutz vor irreversiblen Aktionen |

#### 4. Shield Rebranding

- shield.promptandbuild.de Landing Page: Logo/Header aendern zu "GuardRail PII Shield"
- Footer-Link zu guardrail.promptandbuild.de
- "Part of the GuardRail Security Suite" Tagline
- Bestehende API-Endpunkte bleiben identisch (keine Breaking Changes)

#### 5. GuardRail Landing Update

- guardrail.promptandbuild.de: Module-Sektion mit PII Shield, Audit Trail, Compliance Reporter
- Pricing-Tabelle: Free / Pro (29 EUR) / Compliance Kit (4.900 EUR)
- Stripe-Link aktualisieren auf 29 EUR

## Pricing

| Tier | Preis | Inhalt | Zielgruppe |
|------|-------|--------|-----------|
| Free | 0 EUR | 10 Core Guards + Engine + Doku | Solo-Devs, OSS |
| Pro | 29 EUR/Dev/Monat | 48+ Guards + PII Shield + Audit Trail + Compliance Reporter | Teams 2-50 |
| Compliance Kit | 4.900 EUR einmalig | EU-AI-Act-Mapping + Audit-Template + 2h Setup-Call | CTOs vor Audit |
| Consulting | 300 EUR/h | Custom Guards, Security Review, Integration | Enterprise |

**Revenue-Szenario Jahr 1 (konservativ):**
- 200 Pro-Sitze x 29 EUR x 12 = 69.600 EUR
- 5 Compliance Kits x 4.900 EUR = 24.500 EUR
- 20h Consulting x 300 EUR = 6.000 EUR
- Gesamt: ~100.000 EUR ARR

## Go-to-Market

1. **GitHub** -- Free-Tier bringt Stars, Stars bringen Sichtbarkeit
2. **Content** -- Jeder KI-Agent-Incident ist ein Post: "Wie GuardRail das verhindert haette"
3. **EU AI Act** -- Enforcement ab 2. August 2026, Dringlichkeit nutzen
4. **PII Shield API** -- Nebeneinnahme, fuettert GuardRail-Funnel

## Was wir NICHT bauen

- Kein Dashboard (CLI-first)
- Keine Policy-Engine (zu komplex, zu viel Wettbewerb)
- Keinen Secret-Scanner als eigenes Produkt (GitHub/GitGuardian dominieren)
- Kein Multi-Cloud vor Markvalidierung

## Technische Constraints

- Guards sind Shell-Scripts (bash), kein Python/Node im Guard selbst
- PII Shield Guard nutzt curl fuer API-Call (einzige externe Dependency)
- Audit Trail ist rein lokal (JSONL), kein externer Service
- Compliance Reporter liest nur lokale Dateien, sendet nichts
- Alle neuen Guards muessen den bestehenden PEN-Test-Prozess bestehen
