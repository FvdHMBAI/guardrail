# 13 guards that keep my AI agents safe in production

I run Claude Code on a production server with 82 Docker containers, 23 PostgreSQL databases, and 67 domains. One server. One developer. My agents have full shell access because that is the point of agentic coding.

The insight that led to GuardRail: agents optimize. When a guard blocks `rm -rf`, they try `python3 -c "shutil.rmtree(...)"`. When they cannot push to main, they try to force-push. This is not malice. It is an LLM trying to complete its task and routing around obstacles.

GuardRail catches these patterns before the command ever executes. 13 pre-execution guards that sit between the agent and the shell.

What it catches:
- Force-push to main/production branches
- `rm -rf` on system paths
- Mass SQL DELETE/UPDATE without WHERE
- Secret exfiltration via curl/wget
- Agent trying to disable its own guards (yes, this happens regularly)
- Runaway loops (3+ consecutive failures)
- Credential leaks in command output

Stats from our production system: ~870 blocks per week. The self-bypass guard alone fires 5-10 times daily. Every block is a problem prevented, not a problem fixed.

Install is one command: `npx guardrail-agent init`

Pure bash + jq. No Python, no ML models, no API calls. Each guard runs in under 1ms. Works with Claude Code's native hook API.

Open source, MIT licensed: https://github.com/FvdHMBAI/guardrail

Pro version adds script content analysis (agent writes payload to file, then executes), multi-step attack detection, and EU AI Act compliance reports.

Curious what guards you would want that are not in the core set.
