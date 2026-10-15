# Premium Guards (GuardRail Pro)

These guards are available with a GuardRail Pro subscription.
They contain patterns derived from real production incidents and cover
attack vectors that the 13 core guards do not.

## What's included

GuardRail Pro ships 48 guards. A selection:

| Guard | Protects against |
|-------|------------------|
| `skill_injection_guard` | Prompt injection via SKILL.md, rules, and memory files |
| `multi_step_attack_guard` | Coordinated multi-command reconnaissance and exfiltration sequences |
| `semantic_injection_guard` | Instructions disguised as data in tool output |
| `agent_control_policy_guard` | Policy-based risk scoring per command category |
| `pre_exec_file_scanner` | Scans files before execution for hidden payloads |
| `output_pii_scanner` | Detects emails, phone numbers, JWTs, secrets in output |
| `deploy_branch_guard` | Branch-to-environment mapping enforcement |
| `test_pyramid_guard` | Test coverage enforcement before commits |
| `quality_gate_guard` | Multi-stage quality gates |
| `self_correction_loop_guard` | Detects and breaks infinite retry loops |

## Also included in Pro

- **PII scanning of agent output**
- **Compliance report**: `guardrail compliance-report` with EU AI Act article mapping
- **E-mail support**

## Pricing

GuardRail Pro costs EUR 29 per month. Try it for 14 days without a card: `guardrail upgrade --trial`.

Learn more: https://guardrail.promptandbuild.de
