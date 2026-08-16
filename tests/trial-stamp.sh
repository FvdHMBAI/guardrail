#!/bin/bash
# Trial stamp integrity tests.
# The trial file used to be a bare unix timestamp, so `date +%s > .trial-started`
# granted an unlimited trial. It is now HMAC-signed with the same local key as
# the disable token.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT=$(mktemp -d /tmp/guardrail-trial-stamp.XXXXXX)
trap 'rm -rf "$TMP_ROOT"' EXIT
PASS=0
ok() { PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; exit 1; }

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME"
INSTALL_DIR="$TMP_ROOT/install"
mkdir -p "$INSTALL_DIR"

source "$ROOT/lib/guardrail-license.sh"

# A freshly written stamp is signed and yields a full trial.
_guardrail_write_trial_stamp "$INSTALL_DIR" || fail "could not write a trial stamp"
[ -f "$HOME/.guardrail/disable.key" ] || fail "trial stamp did not create the local key"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "14" ] || fail "fresh trial reports $days days instead of 14"
ok

# The stamp must carry a signature, not just a timestamp.
field_count=$(awk '{print NF}' "$INSTALL_DIR/.trial-started")
[ "$field_count" = "2" ] || fail "trial stamp has $field_count fields, expected timestamp and signature"
ok

# The old reset trick must no longer grant a trial.
date +%s > "$INSTALL_DIR/.trial-started"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "-1" ] || fail "unsigned timestamp granted a $days day trial"
ok

# A forged signature must not grant a trial either.
printf '%s %s\n' "$(date +%s)" "0123456789abcdef0123456789abcdef" > "$INSTALL_DIR/.trial-started"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "-1" ] || fail "forged signature granted a $days day trial"
ok

# Moving the timestamp forward invalidates the signature, so the expiry of a
# genuine trial cannot be pushed out by editing the file.
_guardrail_write_trial_stamp "$INSTALL_DIR"
real_sig=$(awk '{print $2}' "$INSTALL_DIR/.trial-started")
printf '%s %s\n' "$(( $(date +%s) + 864000 ))" "$real_sig" > "$INSTALL_DIR/.trial-started"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "-1" ] || fail "replayed signature on a newer timestamp granted a $days day trial"
ok

# An expired trial reports a non-positive number rather than silently renewing.
expired_ts=$(( $(date +%s) - 15 * 86400 ))
printf '%s %s\n' "$expired_ts" "$(_guardrail_trial_sign "$expired_ts")" > "$INSTALL_DIR/.trial-started"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" -le 0 ] || fail "15-day-old trial still reports $days days left"
ok

# A stamp signed with a different machine's key must not validate.
_guardrail_write_trial_stamp "$INSTALL_DIR"
head -c 32 /dev/urandom | base64 | tr -d '\n' > "$HOME/.guardrail/disable.key"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "-1" ] || fail "stamp from a foreign key granted a $days day trial"
ok

# No trial file at all is not a trial.
rm -f "$INSTALL_DIR/.trial-started"
days=$(_guardrail_trial_days_left "$INSTALL_DIR")
[ "$days" = "-1" ] || fail "missing trial file reported $days days"
ok

printf 'Trial stamp suite: passed=%s failed=0 total=%s\n' "$PASS" "$PASS"
