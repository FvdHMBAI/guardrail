# Show HN: GuardRail -- Pre-execution security guards for AI coding agents

My AI agent deleted a production database table last year. Not maliciously. It was trying to "clean up" during a refactoring task and ran `DELETE FROM profiles WHERE 1=1`.

So I built GuardRail. It sits between the AI agent and the shell, inspecting every command before it executes. Dangerous command? Blocked. Safe command? Runs normally. The agent never even notices.

18 open-source guards (MIT), covering: force-push protection, recursive deletion on system paths, mass SQL without WHERE, secret exfiltration, agent self-bypass attempts, runaway loops, and more.

One interesting finding: agents don't "plan" to bypass your safety controls, but they routinely try. When a guard blocks `rm -rf`, the agent will try `python3 -c "import shutil; shutil.rmtree(...)"` next. We see ~870 blocked commands per week across 15 applications. The self-bypass guard alone catches 5-10 attempts daily.

Technical details:
- Pure bash + jq, no runtime dependencies
- <1ms per guard, <5ms total overhead
- HMAC-signed disable tokens (install-time secret, not forgeable)
- Works with Claude Code natively (hook API), adapters planned for Codex CLI and Gemini CLI

Install: `npx guardrail-agent init`

Security model is honest: this is a seatbelt, not a jail cell. Agent runs as the same OS user, so true isolation needs OS-level controls. But it catches 99% of real incidents, which are accidental or optimization-driven.

GitHub: https://github.com/FvdHMBAI/guardrail
npm: https://www.npmjs.com/package/guardrail-agent
