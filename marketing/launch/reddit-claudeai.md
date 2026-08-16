# Reddit r/ClaudeAI Post

## Title
I built a security layer that blocks Claude Code from running dangerous commands. Here's what it catches.

## Body

I've been running Claude Code in autonomous mode on a production server for about 14 months. 13 apps, 24 databases, 86 Docker containers. One developer (me).

Early on, I learned the hard way that Claude will occasionally try things like:

- `DELETE FROM profiles` (no WHERE clause, across all customer databases)
- `docker rm -f` on a running production container
- `echo $DATABASE_URL` (piping credentials into stdout)
- `rm -rf` in paths it shouldn't touch

So I started writing bash guards. Simple functions that intercept every command before execution and block anything that matches a dangerous pattern. Over 14 months that grew into 177 rules.

I packaged the most universal 20 into an open-source tool called GuardRail. Here's what it looks like in practice:

```
$ guardrail pentest

  Running 92 attack scenarios...

  [BLOCKED] SQL injection via unquoted variable
  [BLOCKED] Mass DELETE without WHERE clause
  [BLOCKED] Credential file echo to stdout
  [BLOCKED] Docker force-remove production container
  [BLOCKED] Path traversal via ../../../etc/passwd
  [BLOCKED] Recursive deletion at root level
  ...

  89/92 attacks blocked (3 require Pro guards)
  All 20 core guards passed.
```

The key thing: when a command is blocked, Claude gets the reason as an error message, adjusts its approach, and tries a safer alternative. It doesn't just fail. It learns within the session.

**How to try it:**

```bash
npx guardrail-agent init     # installs 20 core guards
guardrail pentest             # runs attack simulation
guardrail upgrade --trial     # unlocks 48 Pro guards for 14 days
```

Pure bash, no dependencies, MIT licensed. Works with Claude Code's hook system.

GitHub: https://github.com/FvdHMBAI/guardrail

Curious what dangerous commands others have seen from Claude Code. The multi-step patterns are the scariest, where each individual command looks fine but the sequence is an attack chain.
