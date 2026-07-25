# Guard Catalog

## Core Guards (MIT)

### Pre-Bash Guards

These guards run **before** a command executes. They can block the command (`deny()`)
or add a warning (`warn()`).

#### main_push_guard

Blocks direct pushes to protected branches and destructive git operations.

| Pattern | Action |
|---------|--------|
| `git push origin main` | DENY |
| `git push origin HEAD:main` | DENY |
| `git push --force ...` | DENY |
| `git reset --hard ...` | DENY |
| `git clean -f ...` | DENY |
| `git push origin develop` | PASS |

**Config:** `GUARDRAIL_PROTECTED_BRANCHES` (default: `main master production`)

#### basic_pii_gate

Blocks commands that dump full environment variables or process secrets.

| Pattern | Action |
|---------|--------|
| `env` / `printenv` | DENY |
| `cat /proc/self/environ` | DENY |
| `declare -x` | DENY |
| `docker inspect <container>` | DENY |
| `docker inspect --format '{{.State}}' <c>` | PASS |
| `docker exec <c> env` | DENY |

#### basic_secret_detector

Blocks secret exfiltration to known malicious domains.

| Pattern | Action |
|---------|--------|
| `curl https://webhook.site/...` | DENY |
| `wget https://requestbin.com/...` | DENY |
| `curl -d "$API_KEY" https://...` | DENY |
| `echo "$SECRET" \| base64` | DENY |
| `curl https://api.example.com/health` | PASS |

**Detected domains:** webhook.site, requestbin, pipedream, hookbin,
burpcollaborator, interact.sh, canarytokens

#### destructive_path_guard

Blocks recursive deletion of system-critical paths.

| Pattern | Action |
|---------|--------|
| `rm -rf /etc` | DENY |
| `rm -rf /home/developer/...` | DENY |
| `find /var -delete` | DENY |
| `rm -rf node_modules` | PASS |
| `rm file.txt` | PASS |

**Config:** `GUARDRAIL_PROTECTED_PATHS` (default: `/etc /usr /var /boot`)

#### firewall_flush_guard

Blocks commands that disable or flush firewall rules.

| Pattern | Action |
|---------|--------|
| `iptables -F` / `iptables --flush` | DENY |
| `ufw disable` / `ufw reset` | DENY |
| `nft flush ruleset` | DENY |
| `iptables -L` (list only) | PASS |
| `ufw allow 80` | PASS |

#### service_protection_guard

Blocks stopping or killing critical system services.

| Pattern | Action |
|---------|--------|
| `systemctl stop sshd` | DENY |
| `systemctl disable docker` | DENY |
| `killall postgres` | DENY |
| `pkill nginx` | DENY |
| `systemctl restart myapp` | PASS |

**Config:** `GUARDRAIL_CRITICAL_SERVICES` (default: `sshd nginx postgres docker containerd`)

#### mass_update_guard

Blocks SQL UPDATE/DELETE without WHERE clause on protected tables.
Only active when the command contains `psql`.

| Pattern | Action |
|---------|--------|
| `psql -c "DELETE FROM profiles"` | DENY |
| `psql -c "UPDATE users SET active=false"` | DENY |
| `psql -c "DELETE FROM profiles WHERE id='1'"` | PASS |

**Config:** `GUARDRAIL_PROTECTED_TABLES` (default: `auth.users profiles members`)

### Post-Bash Guards

These guards run **after** a command executes. They analyze the output and add
context via `add_context()`. They cannot block retroactively.

#### env_dump_detector

Detects full environment variable dumps in command output (8+ KEY=VALUE lines).

#### basic_injection_scanner

Detects prompt injection patterns in command output:
- "ignore previous instructions" patterns
- Role override attempts ("you are now", "act as")
- System prompt tags in output

### Post-Edit Guards

These guards run **after** a file is written or edited.

#### error_swallow_guard

Detects catch blocks in critical code paths (payment, webhook, cron, etc.)
that only log errors without re-throwing or notifying.

Only triggers on `.ts/.tsx/.js/.jsx` files with critical path names in the
file path (webhook, payment, cron, api, queue, worker, stripe, booking).

## GuardRail Pro Guards

40+ advanced guards available with a Pro subscription. These contain patterns
derived from real production incidents and cover attack vectors that basic
guards miss.

See [guards/premium/README.md](../guards/premium/README.md) for the full list.
