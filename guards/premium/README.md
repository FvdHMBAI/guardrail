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

## Also included in Pro

- **PEN Test Framework**: 50+ attack patterns from real incidents
- **EU AI Act Compliance Mapping**: Guard-to-article matrix
- **Audit Report Generator**: PDF compliance reports
- **Priority Support**: Response within 24h

## Pricing

| Plan | Price |
|------|-------|
| Pro | EUR 20/dev/month |
| Enterprise | Custom |
| Compliance Kit | EUR 5,000 one-time |

Learn more: https://guardrail.promptandbuild.de
