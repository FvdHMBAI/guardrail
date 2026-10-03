# Contributing to GuardRail

Thanks for your interest in contributing.

## Quick Start

```bash
# Clone the repo and install dev dependencies
git clone https://github.com/FvdHMBAI/guardrail.git
cd guardrail
npm install

# Run the full test suite
npm test
```

> **Note:** `npm install` sets up the development environment. Do not run
> `npx guardrail-agent init` - that installs GuardRail globally into
> `~/.claude/hooks/guardrail/` and is not needed for contributing.

## Ways to Contribute

### Propose a Guard

Open an issue using the [guard proposal template](https://github.com/FvdHMBAI/guardrail/issues/new?template=guard_proposal.md). Describe the attack vector, show an example command, and explain how the guard should respond.

### Write a Guard

New guards are added as **core guards** directly in the repository. There are
three steps:

**1. Create the guard file**

```bash
# Guards live in guards/core/ - name the file after your guard
touch guards/core/my_guard_name.sh
```

Every core guard is a single bash function:

```bash
#!/bin/bash
# Guard: my_guard_name
# One-line description of what it blocks.
# License: MIT

hook_my_guard_name() {
  # Return early if this command is not relevant
  echo "$CMD" | grep -qE 'pattern' || return 0

  # Block: deny "Reason shown to the user."
  # Warn:  allow_with_msg "Warning shown to the user."
  deny "My guard blocked this command."
}
```

**2. Register the guard in the dispatcher**

Open `dispatchers/pre-bash.sh` (for pre-execution guards) or
`dispatchers/post-bash.sh` (for post-execution guards) and add one line in the
guard-call block:

```bash
_guardrail_run hook_my_guard_name
```

**3. Add a test**

Tests live in `tests/new-guards.sh`. Add at least one DENY case and one PASS
case:

```bash
# my_guard_name
setup "dangerous command here"; run_pre; expect_deny "my_guard_name DENY"
setup "safe command here";      run_pre; expect_pass "my_guard_name PASS"
```

Then run the full suite to confirm everything passes:

```bash
npm test
```

Guard requirements:
- Pure bash, no external dependencies beyond jq
- Must have tests in `tests/new-guards.sh`
- Must not break existing tests
- Should handle both the direct command and common obfuscation variants

### Report a Bug

Open an issue with:
- GuardRail version (`guardrail status`)
- Operating system
- The command that was incorrectly blocked or allowed
- Expected behavior

### Improve Documentation

Documentation improvements are always welcome. Small fixes can go directly into a PR against `main`.

## Pull Request Process

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `npm test` - all tests must pass
4. Open a PR against `main`

## Code of Conduct

Be respectful. Focus on the work. We are here to make AI agents safer.
