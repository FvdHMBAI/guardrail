# GuardRail on Windows (WSL2)

GuardRail runs inside WSL2 and works exactly like the Linux installation.
This guide covers what is different on a Windows machine.

## Prerequisites

- **WSL2** with a Linux distribution (Ubuntu 22.04 LTS recommended)
- **Node.js ≥ 18** installed *inside WSL* - not the Windows-side Node.js
- **Claude Code** installed *inside WSL* - hooks are Linux paths; a Windows-side Claude Code install cannot reach them

Install Node.js inside WSL if you have not already:

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## Installation

Run the installer from inside a WSL terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/FvdHMBAI/guardrail/main/install.sh | bash
```

This writes hook paths under `~/.claude/hooks/guardrail/` using Linux paths.
It registers four dispatchers in `~/.claude/settings.json` via `jq`.

## Verify the installation

```bash
guardrail status
```

`status` probes the registered hook with a real deny and prints
`Enforcement verified` only when the hook is wired correctly and actually
blocks. This is the key check on Windows because the failure mode - a
Windows-side Claude Code trying to execute Linux hook paths - fails silently.

## Path rules

**Always work from the WSL filesystem, not from `/mnt/c/`.**

GuardRail hooks fire on every Bash and Edit call. On `/mnt/c/` paths the
9p filesystem boundary adds latency on each call - working from `/home/...`
avoids that and is the supported path.

Windows paths (`C:\Users\...`) are not valid inside WSL and will not work
in guard patterns.

## Non-standard Claude config location

If your Claude config is not at `~/.claude/`, set `GUARDRAIL_CLAUDE_DIR`
before running the installer:

```bash
GUARDRAIL_CLAUDE_DIR=/path/to/your/claude/config \
  curl -fsSL https://raw.githubusercontent.com/FvdHMBAI/guardrail/main/install.sh | bash
```

## Known behaviour differences

**GNU coreutils (good news).** WSL2 with Ubuntu ships a GNU userland, which
is the well-supported case. `realpath -m -s` (used in `edit_path_guard`) is
GNU-only and works correctly on WSL2 Ubuntu. macOS is where the platform
divergence lives, not WSL2.

**Alpine-based WSL.** If you are running Alpine inside WSL, `realpath -m -s`
may fail. Use Ubuntu 22.04 or Debian instead.

**Line endings.** If you cloned the repo on Windows before moving to WSL, run
`dos2unix guards/core/*.sh dispatchers/*.sh` to fix CRLF line endings.

## Running the test suite

From a clone of the repo inside WSL:

```bash
npm test
```

All six suites should pass (regression, adversarial, installer-adversarial,
pre-edit, new-guards, trial-stamp). If they do not, check that Node.js and
`jq` are installed inside WSL, not only on the Windows side.

## Reporting WSL experience

If you run GuardRail on WSL2, your experience is useful to other users.
Open an issue or comment on [#24](https://github.com/FvdHMBAI/guardrail/issues/24)
with your distro, Node version, and whether `npm test` passed.
