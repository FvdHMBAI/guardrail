# Contributing to GuardRail

Thank you for helping make AI coding agents safer.

## How to Contribute

### Reporting Issues

- Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.md) template
- Include: guard name, command that triggered it, expected vs actual behavior

### Proposing New Guards

1. Open an issue with the "Guard Proposal" template
2. Describe: what it protects against, why it matters, example commands
3. Reference any relevant EU AI Act articles

### Writing a Guard

Every guard is a bash function that follows this pattern:

```bash
#!/bin/bash
# GuardRail Core Guard: my_guard
# One-line description of what this guard protects against.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID (pre-bash)
# Shared fns: deny(), warn()

hook_my_guard() {
  # Check for dangerous pattern
  if echo "$CMD" | grep -qE 'dangerous-pattern'; then
    guardrail_audit "My-Guard" "Blocked dangerous pattern" "$(echo "$CMD" | head -c 60)"
    deny "MY-GUARD: Explanation of why this is blocked and what to do instead."
  fi
}
```

### Rules

1. **No hardcoded paths.** Use `GUARDRAIL_*` variables with defaults.
2. **No external dependencies** beyond bash 4+, jq, and standard Unix tools.
3. **Both directions tested.** Every guard needs true positive AND false positive tests.
4. **English messages.** Guard output must be in English.
5. **Function signature:** `hook_<guard_name>()`
6. **Performance:** Guards run on every command. Keep them fast (<50ms).

### Testing

```bash
# Run all tests
./tests/regression.sh

# Syntax check all guards
for f in guards/core/*.sh; do bash -n "$f" && echo "OK: $f"; done
```

### Pull Requests

1. Fork the repo
2. Create a feature branch
3. Add your guard + tests
4. Run `./tests/regression.sh`
5. Submit PR

## Code of Conduct

Be respectful. Focus on making AI coding agents safer for everyone.
