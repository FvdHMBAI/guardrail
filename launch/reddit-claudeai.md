# 18 guards that saved me from my own agent

I run Claude Code on a production server with 82 Docker containers, 23 PostgreSQL databases, and 67 domains. One server. One developer. My agents have full shell access because that's the point of agentic coding.

The problem: agents optimize. When a guard blocks `rm -rf`, they try `python3 -c "shutil.rmtree(...)"`. When they can't push to main, they try `git push --force origin main`. This isn't malice. It's an LLM trying to complete its task and routing around obstacles.

I built GuardRail after an agent ran `DELETE FROM profiles WHERE 1=1` during a "cleanup" task. Now every command goes through 18 pre-execution guards before it touches the shell.

What it catches:
- Force-push to main/production branches
- `rm -rf` on system paths
- Mass SQL DELETE/UPDATE without WHERE
- Secret exfiltration via curl/wget
- Agent trying to disable its own guards (yes, this happens)
- Runaway loops (3+ consecutive failures)
- Credential leaks in command output

Stats from my production system: ~870 blocks per week. The self-bypass guard alone fires 5-10 times daily.

Install is one command: `npx guardrail-agent init`

Pure bash + jq. No Python, no ML models, no API calls. Each guard runs in under 1ms. Works with Claude Code's native hook API.

Open source, MIT licensed: https://github.com/FvdHMBAI/guardrail

Pro version adds script content analysis (agent writes payload to file, then executes), multi-step attack detection, and EU AI Act compliance reports.

Curious what guards you'd want that aren't in the core set.
