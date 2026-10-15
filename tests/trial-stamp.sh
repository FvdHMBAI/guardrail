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

# ---------------------------------------------------------------------------
# `guardrail upgrade --trial` no longer downloads guards or writes a stamp.
# The trial runs via Stripe; the license server answers 410 with
# {error, message, trial_url}. curl is replaced by a stub so no network is used.
# ---------------------------------------------------------------------------
STRIPE_TRIAL="https://buy.stripe.com/00w8wQfCn8Nk4UGgg2es00g"
CLAUDE_DIR="$TMP_ROOT/claude"
CLI_INSTALL="$CLAUDE_DIR/hooks/guardrail"
mkdir -p "$CLI_INSTALL/guards/core" "$TMP_ROOT/bin"
export GUARDRAIL_CLAUDE_DIR="$CLAUDE_DIR"
export GUARDRAIL_API_URL="http://127.0.0.1:9"

# Stub: writes $STUB_BODY to the -o file, prints $STUB_CODE, exits $STUB_EXIT.
cat > "$TMP_ROOT/bin/curl" <<'STUB'
#!/bin/bash
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$out" ] && printf '%s' "${STUB_BODY:-}" > "$out"
printf '%s' "${STUB_CODE:-000}"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$TMP_ROOT/bin/curl"
run_trial() { PATH="$TMP_ROOT/bin:$PATH" bash "$ROOT/bin/guardrail.sh" upgrade --trial 2>&1; }

# 410 from the server: its message and the Stripe link are shown, nothing is installed.
rm -f "$CLI_INSTALL/.trial-started"
out=$(STUB_CODE=410 STUB_BODY='{"error":"Trial moved","message":"Start your 14-day GuardRail Pro trial here.","trial_url":"https://buy.stripe.com/00w8wQfCn8Nk4UGgg2es00g"}' run_trial)
echo "$out" | grep -q "Start your 14-day GuardRail Pro trial here." || fail "410 message from the API not shown"
echo "$out" | grep -q "$STRIPE_TRIAL" || fail "Stripe trial link not shown on 410"
echo "$out" | grep -q "guardrail upgrade <key>" || fail "activation hint missing"
[ ! -f "$CLI_INSTALL/.trial-started" ] || fail "upgrade --trial still writes a trial stamp"
[ ! -d "$CLI_INSTALL/guards/pro" ] || fail "upgrade --trial still installs pro guards"
ok

# Server unreachable: the built-in Stripe link is shown, no stamp.
out=$(STUB_CODE=000 STUB_EXIT=7 run_trial)
echo "$out" | grep -q "$STRIPE_TRIAL" || fail "Stripe link missing when the server is unreachable"
[ ! -f "$CLI_INSTALL/.trial-started" ] || fail "unreachable server led to a trial stamp"
ok

# A trial_url outside buy.stripe.com is ignored.
out=$(STUB_CODE=410 STUB_BODY='{"error":"x","message":"m","trial_url":"https://evil.example/pay"}' run_trial)
echo "$out" | grep -q "evil.example" && fail "non-Stripe trial_url was printed"
echo "$out" | grep -q "$STRIPE_TRIAL" || fail "default Stripe link missing for a non-Stripe trial_url"
ok

# A trial started with an earlier version keeps running and is not touched.
_guardrail_write_trial_stamp "$CLI_INSTALL"
before=$(cat "$CLI_INSTALL/.trial-started")
out=$(STUB_CODE=410 STUB_BODY='{}' run_trial)
echo "$out" | grep -q "Trial already active (14 days remaining)" || fail "running local trial not respected: $out"
[ "$(cat "$CLI_INSTALL/.trial-started")" = "$before" ] || fail "running trial stamp was rewritten"
ok

# An expired local trial points to Stripe and is not renewed.
expired_ts=$(( $(date +%s) - 15 * 86400 ))
printf '%s %s\n' "$expired_ts" "$(_guardrail_trial_sign "$expired_ts")" > "$CLI_INSTALL/.trial-started"
before=$(cat "$CLI_INSTALL/.trial-started")
out=$(STUB_CODE=410 STUB_BODY='{}' run_trial)
echo "$out" | grep -q "Your trial has expired." || fail "expired trial not reported"
echo "$out" | grep -q "$STRIPE_TRIAL" || fail "expired trial does not point to Stripe"
[ "$(cat "$CLI_INSTALL/.trial-started")" = "$before" ] || fail "expired trial stamp was renewed"
ok

printf 'Trial stamp suite: passed=%s failed=0 total=%s\n' "$PASS" "$PASS"
