# Premium Guards (GuardRail Pro)

These guards are available with a GuardRail Pro subscription.
They contain patterns derived from real production incidents and cover
attack vectors that basic guards miss.

## What's included

| Guard | Protects against |
|-------|------------------|
| `advanced_pii_gate` | 15+ PII leak vectors beyond env/printenv (SQL tricks, SSH wrapping, scripting languages) |
| `tabu_gate` | Multi-pattern destructive SQL with script content scanning |
| `script_content_check` | Malicious payloads hidden inside script files |
| `skill_injection_guard` | Prompt injection via SKILL.md, rules, and memory files |
| `multi_step_attack_guard` | Coordinated multi-command reconnaissance and exploit sequences |
| `semantic_injection_guard` | Instructions disguised as data in tool output |
| `agent_control_policy_guard` | Policy-based risk scoring per command category |
| `anti_self_bypass_guard` | Prevents AI agents from creating their own bypass tokens |
| `gate_file_guard` | Gate file workflows with anti-bypass protection |
| `pre_exec_file_scanner` | Scans files before execution for hidden payloads |
| `output_pii_scanner` | Detects emails, phone numbers, JWTs, secrets in output |
| `deploy_branch_guard` | Branch-to-environment mapping enforcement |
| `test_pyramid_guard` | Test coverage enforcement before commits |
| `quality_gate_guard` | Multi-stage quality gates |
| `self_correction_loop_guard` | Detects and breaks infinite retry loops |
| `...and 20+ more` | Deploy verification, schema checks, auth guards |

## Data Protection & Compliance

| Guard | Protects against |
|-------|------------------|
| `post_pii_shield_guard` | Personal data in agent outputs (10 EU countries, 3-tier classification) |
| `post_audit_trail_guard` | Missing audit evidence (structured JSONL logging of all agent actions) |

## Also included in Pro

- **PII Shield**: Real-time PII scanning via GuardRail PII Shield API (IBAN, tax IDs, names, addresses across DE/AT/CH/SE/FR/NL/ES/IT/PL/PT/BE)
- **Audit Trail**: Structured JSONL audit log with daily rotation and configurable retention
- **Compliance Reporter**: `guardrail compliance-report` with EU AI Act article mapping
- **PEN Test Framework**: 50+ attack patterns from real incidents
- **Priority Support**: Response within 24h

## Pricing

| Plan | Price |
|------|-------|
| Pro | EUR 29/dev/month |
| Enterprise | Custom |
| Compliance Kit | EUR 4,900 one-time |

Learn more: https://guardrail.promptandbuild.de
