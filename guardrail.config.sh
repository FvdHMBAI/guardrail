#!/bin/bash
# GuardRail Configuration
# Copy this file to your project root and customize as needed.
# All values have sensible defaults that work without configuration.

# --- Paths ---
# Where GuardRail stores audit logs
GUARDRAIL_AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"

# Directory for runtime logs
GUARDRAIL_LOG_DIR="${GUARDRAIL_LOG_DIR:-/var/log/guardrail}"

# Directory for temporary state files (gate files, counters)
GUARDRAIL_STATE_DIR="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"

# Where GuardRail is installed
GUARDRAIL_HOME="${GUARDRAIL_HOME:-$HOME/.guardrail}"

# Claude Code config directory
GUARDRAIL_CLAUDE_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}"

# --- Guards ---
# Comma-separated list of enabled core guards (empty = all core guards)
GUARDRAIL_ENABLED_GUARDS="${GUARDRAIL_ENABLED_GUARDS:-}"

# Directory for custom guards (loaded after core guards)
GUARDRAIL_CUSTOM_GUARDS_DIR="${GUARDRAIL_CUSTOM_GUARDS_DIR:-./custom-guards}"

# --- Behavior ---
# Strict mode: true = deny() blocks execution, false = warn only
GUARDRAIL_STRICT_MODE="${GUARDRAIL_STRICT_MODE:-true}"

# --- Database Protection ---
# Space-separated list of protected tables (blocked from DROP/TRUNCATE/direct writes)
GUARDRAIL_PROTECTED_TABLES="${GUARDRAIL_PROTECTED_TABLES:-auth.users profiles members}"

# Space-separated list of PII columns (blocked from SELECT)
GUARDRAIL_PII_COLUMNS="${GUARDRAIL_PII_COLUMNS:-email full_name first_name last_name phone encrypted_password recovery_token confirmation_token}"

# Protected branches (blocked from direct push)
GUARDRAIL_PROTECTED_BRANCHES="${GUARDRAIL_PROTECTED_BRANCHES:-main master production}"

# --- Protected Paths ---
# Space-separated list of paths that should never be deleted/overwritten
GUARDRAIL_PROTECTED_PATHS="${GUARDRAIL_PROTECTED_PATHS:-/home /etc /var/lib/docker /var/lib/postgresql}"

# Critical services (blocked from kill/stop)
GUARDRAIL_CRITICAL_SERVICES="${GUARDRAIL_CRITICAL_SERVICES:-docker sshd ssh traefik postgresql postgres nginx}"

# --- Notifications ---
# Optional webhook command for critical events (leave empty to disable)
# Called as: $GUARDRAIL_WEBHOOK_CMD "<guard_name>" "<reason>" "<severity>"
GUARDRAIL_WEBHOOK_CMD="${GUARDRAIL_WEBHOOK_CMD:-}"

# --- Limits ---
# Maximum rows for UPDATE/DELETE without WHERE (0 = block all)
GUARDRAIL_MAX_UNFILTERED_ROWS="${GUARDRAIL_MAX_UNFILTERED_ROWS:-0}"

# Maximum files to scan in pre_exec_file_scanner
GUARDRAIL_MAX_FILE_SCAN="${GUARDRAIL_MAX_FILE_SCAN:-5}"
