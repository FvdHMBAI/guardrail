# Show HN: GuardRail -- Pre-execution security guards for AI coding agents

I run 82 Docker containers, 23 PostgreSQL databases, and 15 applications on a single server. My AI agents have full shell access. That is the point of agentic coding.

But agents optimize. When you block `rm -rf`, they try `python3 -c "import shutil; shutil.rmtree(...)"`. When a gate file is missing, they write it themselves. Not malicious. Just task-oriented.

So I built GuardRail. It sits between the AI agent and the shell, inspecting every command before it executes. Dangerous command? Blocked. Safe command? Runs normally. The agent never even notices.

18 open-source guards (MIT), covering: force-push protection, recursive deletion on system paths, mass SQL without WHERE, secret exfiltration, agent self-bypass attempts, runaway loops, and more.

Our production system blocks ~870 commands per week across 15 applications. The self-bypass guard alone catches 5-10 attempts daily. Every one of those is a problem we caught before it happened.

Technical details:
- Pure bash + jq, no runtime dependencies
- <1ms per guard, <5ms total overhead
- HMAC-signed disable tokens (install-time secret, not forgeable)
- Works with Claude Code natively (hook API), adapters planned for Codex CLI and Gemini CLI

Install: `npx guardrail-agent init`

Security model is honest: this is a seatbelt, not a jail cell. Agent runs as the same OS user, so true isolation needs OS-level controls. But it catches 99% of real incidents, which are accidental or optimization-driven.

GitHub: https://github.com/FvdHMBAI/guardrail
npm: https://www.npmjs.com/package/guardrail-agent
