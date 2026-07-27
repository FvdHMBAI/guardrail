# GuardRail Guard Classification

Source: Production guard system (139 guards)
Classified: 2026-07-25
Model: Open Core (MIT framework + proprietary premium)

## Summary

| Category | Count | Description |
|----------|-------|-------------|
| **Core (MIT)** | 10 | Universal guards any dev could write in <1h. No incident knowledge. |
| **Premium (Pro)** | 48 | Derived from production incidents. Advanced attack detection. |
| **Internal** | 91 | Domain-specific, only relevant to our setup. |

---

## Core Guards (Open Source, MIT)

Generic protection every AI coding agent needs. Written from scratch, no incident knowledge.

| Guard | Dispatcher | Description |
|-------|-----------|-------------|
| `main_push_guard` | pre-bash | Blocks direct push to main/master/production, force push, git reset --hard |
| `basic_pii_gate` | pre-bash | Blocks env/printenv, /proc/environ, docker inspect without --format |
| `basic_secret_detector` | pre-bash | Blocks API key hardcoding, exfiltration to known domains, base64-encoding of secrets |
| `destructive_path_guard` | pre-bash | Blocks rm -rf on critical paths (/, /home, /etc, /var) |
| `firewall_flush_guard` | pre-bash | Blocks iptables -F, ufw reset, nft flush ruleset |
| `service_protection_guard` | pre-bash | Blocks stop/kill on critical services (docker, postgres, sshd, traefik) |
| `mass_update_guard` | pre-bash | Blocks SQL UPDATE/DELETE without WHERE clause on protected tables |
| `env_dump_detector` | post-bash | Detects KEY=VALUE dumps in command output (environment leak) |
| `basic_injection_scanner` | post-bash | Detects prompt injection patterns in tool output |
| `error_swallow_guard` | post-edit | Warns when catch blocks swallow errors in critical code paths |

---

## Premium Guards (GuardRail Pro)

Advanced guards derived from real production incidents. Each contains non-obvious
patterns that take months of operation to discover.

| Guard | Category | Description |
|-------|----------|-------------|
| `tabu_gate` | Database | Multi-pattern destructive SQL blocking with script content scanning |
| `advanced_pii_gate` | Privacy | 15+ PII vectors: SQL tricks, SSH wrapping, scripting language access, .env reading |
| `gate_file_guard` | Integrity | Gate file mechanism with anti-bypass protection |
| `pre_exec_file_scanner` | Security | Scans referenced files before execution for malicious payloads |
| `script_content_check` | Security | Detects tabu patterns hidden inside script files |
| `agent_control_policy_guard` | Governance | Policy-based risk assessment per command category |
| `anti_self_bypass_guard` | Integrity | Prevents AI agent from creating its own bypass tokens |
| `multi_step_attack_guard` | Security | Detects coordinated multi-command attack sequences |
| `semantic_injection_guard` | Security | Detects instructions disguised as data in tool output |
| `skill_injection_guard` | Security | Detects prompt injection in skill/rule/memory files |
| `output_pii_scanner` | Privacy | Scans command output for emails, phone numbers, JWTs, secrets |
| `pii_deutsch_guard` | Privacy | Detects German PII (IBAN, Steuer-ID, Versichertennummer) |
| `secret_output_guard` | Secrets | Blocks secret leaks in terminal output (docker inspect, JWT echo) |
| `silent_failure_detector` | Reliability | Detects swallowed errors in command output |
| `prompt_injection_scanner` | Security | Advanced injection detection with pattern library |
| `deploy_branch_guard` | DevOps | Ensures only correct branches get deployed |
| `worktree_checkout_guard` | DevOps | Warns when checking out in main working directory |
| `branch_guard` | DevOps | Blocks commits on protected branches |
| `test_pyramid_guard` | Quality | Enforces test pyramid before commits |
| `quality_gate_guard` | Quality | Quality gate enforcement before commits |
| `pre_mortem_guard` | Quality | Enforces pre-mortem analysis before critical operations |
| `cross_review_guard` | Quality | Enforces cross-LLM review before commits |
| `docker_build_guard` | DevOps | Security checks on Docker builds |
| `post_db_schema_change_verify` | Database | Verifies GRANT/RLS/PostgREST reload after schema changes |
| `post_deploy_https_verify` | DevOps | HTTPS reachability check after deploy |
| `post_container_health_verify` | DevOps | Container health check after restart |
| `post_deploy_stability_recheck` | DevOps | Delayed recheck after deploy |
| `hook_pentest_guard` | Security | Enforces PEN test before guard commits |
| `db_backup_gate` | Database | Requires backup confirmation before destructive DB ops |
| `npm_audit_guard` | Dependencies | Enforces npm audit after install |
| `license_compliance_guard` | Legal | Checks licenses on npm install (blocks GPL in MIT projects) |
| `message_post_guard` | Communications | Blocks message sending without explicit approval |
| `auth_migration_guard` | Auth | Enforces password reset checklist on auth migrations |
| `email_link_validation_guard` | Quality | Validates links in email templates |
| `mcp_integrity_guard` | Integrity | Checks MCP server integrity |
| `self_correction_loop_guard` | Reliability | Detects infinite correction loops (>5 retries) |
| `password_sonderzeichen_guard` | Auth | Blocks special chars in generated passwords (shell escape issues) |
| `completion_verification_guard` | Quality | Injects verification reminder after substantial work |

---

## Internal Guards (not included)

Domain-specific guards tailored to a particular production environment.
Not included in any release. Shown here only for completeness.

91 guards across categories: domain-specific app logic, knowledge base,
deploy verification, code quality, session management, and workflow automation.

---

## Dispatcher Mapping

| Dispatcher | Core | Premium (reference) | Handles |
|-----------|------|---------------------|---------|
| pre-bash | 7 | 20+ | Pre-execution blocking |
| post-bash | 2 | 10+ | Output analysis |
| post-edit | 1 | 5+ | File change feedback |
| **Total Core** | **10** | | |
