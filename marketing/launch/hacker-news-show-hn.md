# Hacker News Show HN

## Title (78 chars)
Show HN: GuardRail, pre-execution security guards for AI coding agents (bash)

## Body

AI coding agents (Claude Code, Cursor, Windsurf) run shell commands with your user's full privileges. There's no sandboxing between "the agent decided to run this" and "the command executed." If the agent hallucinates a destructive command, it runs.

GuardRail is a set of bash scripts that hook into the agent's command pipeline and intercept commands before execution. Each guard is a function that receives the command string, pattern-matches against known dangerous operations, and either allows or blocks.

Example: `guard_mass_update` blocks any DELETE/UPDATE/DROP without a WHERE clause. `guard_exec_injection` catches shell metacharacters in interpolated variables. `guard_secret_exposure` prevents commands that would echo credentials to stdout.

Technical details:

- Pure bash, no dependencies, no runtime, no cloud calls
- Works via Claude Code's hook system (pre-bash, post-bash, stop hooks)
- Each guard runs in under 1ms. 20 guards add <20ms total overhead
- Ships with `guardrail pentest` that runs 92 adversarial attack scenarios
- Tar-slip protection on all archive extractions
- MIT licensed

Install: `npx guardrail-agent init`

I've been running 177 guard rules on a production server (13 apps, 24 PostgreSQL databases, 86 Docker containers) for 14 months. The system blocks about 1,400 dangerous operations per week. Most are false positives from overly cautious guards, which is the correct failure mode.

20 core guards are free. 48 additional guards for deeper patterns (multi-step attacks, EU AI Act compliance mapping) are available with a 14-day trial.

Source: https://github.com/FvdHMBAI/guardrail
Docs: https://guardrail.promptandbuild.de

Interested in what attack vectors you've seen with AI agents. The threat model is different from traditional security because the "attacker" is your own agent making a mistake.
