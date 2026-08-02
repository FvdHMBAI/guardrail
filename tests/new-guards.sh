#!/bin/bash
# GuardRail New Guards Test Suite
# Tests for guards added in v0.3.0
# License: MIT

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
GUARDS_DIR="$REPO_DIR/guards/core"
LIB_DIR="$REPO_DIR/lib"
P=0; F=0; ERRS=()

ok() { P=$((P+1)); }
fail() { F=$((F+1)); ERRS+=("$1"); }

check() {
  local name="$1" expect="$2" desc="$3"
  case "$expect" in
    DENY)  echo "$RESULT" | grep -qiE "DENY|blocked" && ok || fail "[$name] $desc expected DENY" ;;
    PASS)  echo "$RESULT" | grep -qiE "DENY|blocked" && fail "[$name] $desc expected PASS" || ok ;;
    DETECT) echo "$RESULT" | grep -qiE "DETECTED|LEAK|WANDERING|BUILD ERROR|TEST FAIL|RUNTIME ERROR|UNCOMMITTED|correction" && ok || fail "[$name] $desc expected DETECT" ;;
    SILENT) echo "$RESULT" | grep -qiE "DETECTED|LEAK|WANDERING|correction" && fail "[$name] $desc expected SILENT" || ok ;;
    WARN) echo "$RESULT" | grep -qiE "WARN|warning|budget" && ok || fail "[$name] $desc expected WARN" ;;
  esac
}

run_pre() {
  local gf="$1" fn="$2" cmd="$3"
  RESULT=$(
    source "$LIB_DIR/guardrail-common.sh"
    source "$GUARDS_DIR/$gf"
    CMD="$cmd"; CMD_SHELL="$cmd"; SESSION_ID="test-$$"; OUTPUT=""; FILE_PATH=""; R=""
    deny() { R="DENY: $1"; }; allow_with_msg() { R="WARN: $1"; }; warn() { R="WARN: $1"; }
    $fn; echo "${R:-PASS}"
  )
}

run_post() {
  local gf="$1" fn="$2" cmd="$3" out="$4"
  RESULT=$(
    source "$LIB_DIR/guardrail-common.sh"
    source "$GUARDS_DIR/$gf"
    CMD="$cmd"; CMD_SHELL="$cmd"; SESSION_ID="test-$$"; OUTPUT="$out"; FILE_PATH=""; R=""
    add_context() { R="DETECTED: $1"; }
    $fn; echo "${R:-PASS}"
  )
}

echo "=== GuardRail New Guards Test Suite ==="

# --- Phase 0: Syntax check all new guards ---
echo ""
echo "Phase 0: Syntax"
for g in force_push_guard.sh wandering_detector.sh self_correction_loop.sh \
         self_bypass_guard.sh large_diff_guard.sh credential_leak_guard.sh \
         deploy_branch_guard.sh tool_call_budget_guard.sh uncommitted_code_guard.sh; do
  if [ -f "$GUARDS_DIR/$g" ]; then
    bash -n "$GUARDS_DIR/$g" 2>/dev/null && ok || fail "SYNTAX: $g"
  else
    fail "MISSING: $g"
  fi
done

# --- Phase 1: force_push_guard ---
echo "Phase 1: force_push_guard"
run_pre force_push_guard.sh hook_force_push_guard "git push --force origin main"
check force_push DENY "force push to main"

run_pre force_push_guard.sh hook_force_push_guard "git push --force-with-lease origin main"
check force_push DENY "force-with-lease to main"

run_pre force_push_guard.sh hook_force_push_guard "git push -f origin feature"
check force_push DENY "force push to feature (strict mode)"

run_pre force_push_guard.sh hook_force_push_guard "git push origin develop"
check force_push PASS "regular push to develop"

run_pre force_push_guard.sh hook_force_push_guard "git push origin main"
check force_push PASS "regular push to main (no --force)"

run_pre force_push_guard.sh hook_force_push_guard "ls -la"
check force_push PASS "non-git command"

# --- Phase 2: wandering_detector ---
echo "Phase 2: wandering_detector"
# Clean state
rm -f /tmp/guardrail/wandering-test-$$ 2>/dev/null

run_post wandering_detector.sh hook_wandering_detector "curl localhost:3000" "Connection refused"
check wandering PASS "first failure (no detect yet)"

run_post wandering_detector.sh hook_wandering_detector "curl localhost:3001" "Connection refused"
check wandering PASS "second failure (warning only)"

run_post wandering_detector.sh hook_wandering_detector "curl localhost:3002" "ECONNREFUSED"
check wandering DETECT "third failure (threshold reached)"

run_post wandering_detector.sh hook_wandering_detector "curl localhost:4000" "404 Not Found"
check wandering DETECT "fourth failure (still blocked)"

run_post wandering_detector.sh hook_wandering_detector "ls" ""
check wandering SILENT "successful command after failures"

rm -f /tmp/guardrail/wandering-test-$$ 2>/dev/null

run_post wandering_detector.sh hook_wandering_detector "psql -d mydb" "database \"mydb\" does not exist"
check wandering PASS "db not found (first occurrence)"

run_post wandering_detector.sh hook_wandering_detector "docker exec foo" "no such container: foo"
check wandering PASS "container not found (second occurrence)"

rm -f /tmp/guardrail/wandering-test-$$ 2>/dev/null

# --- Phase 3: self_correction_loop ---
echo "Phase 3: self_correction_loop"
run_post self_correction_loop.sh hook_self_correction_loop "npm run build" "Build failed: Module not found"
check correction DETECT "build failure"

run_post self_correction_loop.sh hook_self_correction_loop "npx tsc" "error TS2345: Argument of type 'string'"
check correction DETECT "typescript error"

run_post self_correction_loop.sh hook_self_correction_loop "npm test" "FAIL src/utils.test.ts"
check correction DETECT "test failure"

run_post self_correction_loop.sh hook_self_correction_loop "node app.js" "TypeError: Cannot read property 'map' of undefined"
check correction DETECT "runtime TypeError"

run_post self_correction_loop.sh hook_self_correction_loop "node app.js" "ENOENT: no such file or directory"
check correction DETECT "ENOENT error"

run_post self_correction_loop.sh hook_self_correction_loop "npm run build" "Build succeeded. 0 errors."
check correction SILENT "successful build"

run_post self_correction_loop.sh hook_self_correction_loop "npm test" "Tests: 15 passed, 15 total"
check correction SILENT "all tests passed"

# --- Phase 4: self_bypass_guard ---
echo "Phase 4: self_bypass_guard"
run_pre self_bypass_guard.sh hook_self_bypass_guard "touch /tmp/guardrail-gate-approved"
check bypass DENY "touch on gate file"

run_pre self_bypass_guard.sh hook_self_bypass_guard "echo ok > /tmp/guardrail-gate-build-passed"
check bypass DENY "redirect to gate file"

run_pre self_bypass_guard.sh hook_self_bypass_guard "tee /tmp/guardrail-gate-skip < /dev/null"
check bypass DENY "tee to gate file"

run_pre self_bypass_guard.sh hook_self_bypass_guard "touch /tmp/my-regular-file"
check bypass PASS "touch on non-gate file"

run_pre self_bypass_guard.sh hook_self_bypass_guard "echo hello"
check bypass PASS "regular echo"

# --- Phase 5: credential_leak_guard ---
echo "Phase 5: credential_leak_guard"
run_post credential_leak_guard.sh hook_credential_leak_guard "cat config" "AKIAIOSFODNN7EXAMPLE"
check cred_leak DETECT "AWS access key"

run_post credential_leak_guard.sh hook_credential_leak_guard "cat .env" 'api_key="sk-ant-api03-abcdef1234567890abcdef"'
check cred_leak DETECT "Anthropic key"

run_post credential_leak_guard.sh hook_credential_leak_guard "env" "DATABASE_URL=postgres://user:p4ssw0rd@db.example.com/prod"
check cred_leak DETECT "database connection string"

run_post credential_leak_guard.sh hook_credential_leak_guard "cat key.pem" "-----BEGIN RSA PRIVATE KEY-----"
check cred_leak DETECT "private key"

run_post credential_leak_guard.sh hook_credential_leak_guard "echo test" 'ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789'
check cred_leak DETECT "GitHub token"

run_post credential_leak_guard.sh hook_credential_leak_guard "ls" "file1.txt  file2.txt  file3.txt"
check cred_leak SILENT "clean output"

run_post credential_leak_guard.sh hook_credential_leak_guard "echo" "Build succeeded with 0 errors"
check cred_leak SILENT "normal build output"

# --- Phase 6: tool_call_budget_guard ---
echo "Phase 6: tool_call_budget_guard"
rm -f /tmp/guardrail/tool-calls-test-$$ 2>/dev/null

# Simulate 24 calls (under warn threshold)
for i in $(seq 1 24); do
  run_pre tool_call_budget_guard.sh hook_tool_call_budget_guard "echo call $i" >/dev/null 2>&1
done
run_pre tool_call_budget_guard.sh hook_tool_call_budget_guard "echo call 25"
check budget WARN "25th call triggers warning"

# Simulate up to 49
for i in $(seq 26 49); do
  run_pre tool_call_budget_guard.sh hook_tool_call_budget_guard "echo call $i" >/dev/null 2>&1
done
run_pre tool_call_budget_guard.sh hook_tool_call_budget_guard "echo call 50"
check budget DENY "50th call triggers block"

rm -f /tmp/guardrail/tool-calls-test-$$ 2>/dev/null

# --- Summary ---
echo ""
echo "========================="
echo "  PASS: $P  FAIL: $F"
echo "========================="

if [ "$F" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRS[@]}"; do echo "  - $e"; done
  exit 1
fi
