# Contributing to GuardRail

Thanks for your interest in contributing.

## Quick Start

```bash
# Clone and install
git clone https://github.com/FvdHMBAI/guardrail.git
cd guardrail
npx guardrail-agent init

# Run the test suite
guardrail pentest
```

## Ways to Contribute

### Propose a Guard

Open an issue using the [guard proposal template](https://github.com/FvdHMBAI/guardrail/issues/new?template=guard_proposal.md). Describe the attack vector, show an example command, and explain how the guard should respond.

### Write a Guard

```bash
guardrail new my_guard_name
```

This creates a guard template and a matching test file. Edit both, run `guardrail pentest`, and open a PR.

Guard requirements:
- Pure bash, no external dependencies beyond jq
- Must have a matching test in the PEN-test suite
- Must not break existing tests
- Should handle both the direct command and common obfuscation variants

### Report a Bug

Open an issue with:
- GuardRail version (`guardrail status`)
- Operating system
- The command that was incorrectly blocked or allowed
- Expected behavior

### Improve Documentation

Documentation improvements are always welcome. Small fixes can go directly into a PR.

## Pull Request Process

1. Fork the repo and create a branch from `develop`
2. Make your changes
3. Run `guardrail pentest` -- all tests must pass
4. Open a PR against `develop`

## Code of Conduct

Be respectful. Focus on the work. We are here to make AI agents safer.
