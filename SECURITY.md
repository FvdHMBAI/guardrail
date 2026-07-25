# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in GuardRail, please report it
responsibly. **Do not open a public issue.**

1. Email: security@promptandbuild.de
2. Include: description, reproduction steps, impact assessment
3. We will acknowledge within 48 hours
4. We aim to provide a fix within 7 days for critical issues

## Scope

GuardRail is a pre-execution guard system. Vulnerabilities in scope include:

- Guard bypass techniques (commands that should be blocked but are not)
- Dispatcher logic errors that skip guards
- Configuration injection (manipulating GUARDRAIL_* variables to weaken guards)
- Audit log tampering or evasion

Out of scope:

- Vulnerabilities in Claude Code, Cursor, or other AI tools themselves
- Issues that require root access (GuardRail assumes the host is trusted)
- Social engineering of the AI agent (GuardRail guards commands, not conversations)

## Responsible Disclosure

We follow a 90-day disclosure policy. After reporting, we will:

1. Confirm the vulnerability
2. Develop and test a fix
3. Release the fix
4. Credit you in the changelog (unless you prefer anonymity)

After 90 days, you may disclose publicly regardless of fix status.
