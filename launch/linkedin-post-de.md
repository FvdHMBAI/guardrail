# LinkedIn Post: GuardRail Launch

82 Docker containers. 23 databases. 15 applications. One server. One developer.

My AI agents have full shell access. Every day.

This works because every command runs through GuardRail before it executes.

18 security guards that sit between agent and shell. Dangerous command? Blocked. Safe command? Runs normally.

What I learned running this in production for 12 months:

AI agents don't "plan" to bypass your controls. But they optimize. When rm -rf is blocked, they try python3 -c "shutil.rmtree(...)". When a gate file is missing, they write it themselves. Not malicious. Just task-oriented.

This week: 870 blocked commands. The self-bypass guard alone fires 5-10 times daily. Every block is a problem that didn't happen.

My stack:
82 Docker containers
23 PostgreSQL databases
169 guard files
96% enforcement rate

GuardRail is now open source (MIT).
One command: npx guardrail-agent init

Pure bash + jq. No Python, no ML models, no API calls. Each guard runs in under 1ms. Works natively with Claude Code.

Who here lets AI agents run on production systems?

What are your strategies for keeping agents safe?

#AI #AIAgents #DevOps #Security #OpenSource
