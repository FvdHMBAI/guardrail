# Product Hunt Launch Draft

## Tagline (54 chars)
Pre-execution security guards for AI coding agents

## Description (248 chars)
GuardRail intercepts dangerous commands before your AI agent executes them. Pure bash, zero dependencies, MIT licensed. 20 core guards free, 48 Pro guards with a 14-day trial. Works with Claude Code, Cursor, Windsurf, and any MCP-compatible agent.

## First Comment (Maker's Story)

Hey everyone, I'm Frederik.

Last year I started running AI agents autonomously on a production server with 13 apps and 24 databases. Within the first week, an agent tried to DELETE FROM profiles without a WHERE clause. Across all customer databases.

That's when I started building guards. Simple bash scripts that intercept every command before execution and block anything dangerous. No ML, no API calls, no external dependencies. Just pattern matching at the shell level, running in under 1ms per guard.

After 14 months, I have 177 guard rules in production. They've blocked mass deletions, prevented credential leaks, stopped unauthorized Docker operations, and caught prompt injection attempts.

I packaged the best patterns into GuardRail so others can use them too. The core 20 guards are free and open source. They cover the most common attack vectors: mass data operations, credential exposure, destructive Docker commands, and path traversal.

The 48 Pro guards go deeper into multi-step attack chains, compliance patterns (EU AI Act mapping), and industry-specific protections. You can try them free for 14 days.

I'd love feedback on what guards you'd want to see next. The attack surface for AI agents is still largely uncharted territory.

## 5 Key Features

1. **Pre-execution, not post-mortem** - Blocks commands before they run. Not an audit log you read after the damage is done.
2. **Pure bash, zero dependencies** - No runtime, no API calls, no cloud connection. Ships as shell scripts that hook into your agent's command pipeline.
3. **Sub-millisecond overhead** - Each guard runs in under 1ms. 20 guards add less than 20ms to any command.
4. **Built-in penetration testing** - `guardrail pentest` runs 92 attack scenarios against your guards and reports what gets through.
5. **EU AI Act compliance mapping** - Pro guards map to specific EU AI Act articles. Generate compliance reports with `guardrail compliance-report`.

## Pricing

- **Core (Free)**: 20 guards, MIT licensed, forever free
- **Pro Trial**: All 48 Pro guards free for 14 days, no credit card
- **Pro ($29/month)**: 48 Pro guards, compliance reports, priority updates

## Screenshots to Capture

1. Terminal: `guardrail init` output (clean install flow)
2. Terminal: `guardrail status` showing active guards with trial countdown
3. Terminal: `guardrail pentest` output showing blocked attacks
4. Terminal: A real blocked command (DELETE without WHERE)
5. Landing page hero section
6. Architecture diagram from README (the hook pipeline)
