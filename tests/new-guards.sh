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

# --- Phase: public_publish_guard ---
echo "Phase: public_publish_guard"
bash -n "$GUARDS_DIR/public_publish_guard.sh" 2>/dev/null && ok || fail "SYNTAX: public_publish_guard.sh"
pp() { run_pre public_publish_guard.sh hook_public_publish_guard "$2"; check public_publish "$1" "$3"; }

# Positive: must be blocked
pp DENY 'gh repo create my-leak --public' "repo create --public"
pp DENY 'gh repo create my-leak --public --source=. --push' "repo create --public with push"
pp DENY 'gh repo create acme/tool --public=true' "repo create --public=true"
pp DENY 'gh repo create my-leak --source=. --push' "repo create without visibility"
pp DENY 'gh repo create' "bare repo create"
pp DENY 'gh repo edit acme/tool --visibility public --accept-visibility-change-consequences' "repo edit visibility public"
pp DENY 'gh repo edit acme/tool --visibility=public' "repo edit visibility=public"
pp DENY 'gh gist create notes.md --public' "gist create --public"
pp DENY 'gh gist create -p dump.sql' "gist create -p"
pp DENY 'gh gist create -wp dump.sql' "gist create combined -wp"
pp DENY 'gh api -X PATCH repos/acme/tool -F private=false' "api private=false"
pp DENY 'gh api -X PATCH repos/acme/tool -f visibility=public' "api visibility=public"
pp DENY $'gh api repos/acme/tool --method PATCH --input - <<< \'{"private":false}\'' "api JSON private:false"
pp DENY 'gh api user/repos -f name=leak' "api create repo without private"
pp DENY 'gh api orgs/acme/repos -f name=leak -F private=false' "api org repo private=false"
pp DENY 'gh api gists -F public=true -f files[a.txt][content]=x' "api public gist"
pp DENY $'gh api graphql -f query=\'mutation { createRepository(input: {name: "x", visibility: PUBLIC}) { repository { url } } }\'' "graphql createRepository PUBLIC"
pp DENY $'curl -X POST -H "Authorization: token $T" https://api.github.com/user/repos -d \'{"name":"leak"}\'' "curl create repo default public"
pp DENY $'curl -X POST https://api.github.com/user/repos -d \'{"name":"leak","private":false}\'' "curl create repo private:false"
pp DENY $'curl -X POST https://api.github.com/gists -d \'{"public":true,"files":{"a.txt":{"content":"x"}}}\'' "curl public gist"
pp DENY $'curl -X PATCH https://api.github.com/repos/acme/tool -d \'{"private": false}\'' "curl flip private false"
pp DENY 'glab repo create tool --public' "glab public project"

# Adversarial: quotes, line breaks, variables, wrappers
pp DENY $'gh repo create "my-leak" \'--public\'' "quoted --public"
pp DENY $'gh repo create my-leak \\\n  --public \\\n  --push' "line continuation"
pp DENY $'cd /tmp\ngh repo create my-leak --public' "second line of multi-line command"
pp DENY 'VIS=--public; gh repo create my-leak $VIS' "visibility via variable"
pp DENY 'F=--public && gh gist create $F secrets.env' "gist public via variable"
pp DENY 'V=public; gh repo edit acme/tool --visibility $V' "repo edit visibility via variable"
pp DENY 'gh api -X PATCH repos/acme/tool -F private=$P' "api private from variable"
pp DENY '/usr/local/bin/gh repo create my-leak --public' "absolute path to gh"
pp DENY 'env GH_TOKEN=x gh repo create my-leak --public' "env wrapper"
pp DENY 'bash -c "gh repo create my-leak --public"' "bash -c wrapper"
pp DENY '(cd app && gh repo create my-leak --public)' "subshell"
pp DENY 'echo x && gh   repo   create   my-leak   --public' "extra whitespace"
pp DENY $'echo \'{"name":"x","private":false}\' | gh api repos/acme/tool -X PATCH --input -' "body piped into gh api"
pp DENY $'gh api user/repos --input - <<EOF\n{"name":"leak"}\nEOF' "heredoc body without private"
pp DENY $'curl -X POST https://api.github.com/user/repos \\\n  -d \'{"name":"leak",\n  "private": false}\'' "curl body over several lines"

# Negative: must stay allowed
pp PASS 'gh repo create my-tool --private' "repo create --private"
pp PASS 'gh repo create my-tool --private --source=. --push' "repo create --private push"
pp PASS 'gh repo create acme/tool --internal' "repo create --internal"
pp PASS 'gh repo view acme/tool' "repo view"
pp PASS 'gh repo list acme --visibility public' "repo list filtered by public"
pp PASS 'gh repo edit acme/tool --visibility private --accept-visibility-change-consequences' "repo edit to private"
pp PASS 'gh repo edit acme/tool --description "new text"' "repo edit description"
pp PASS 'gh gist list' "gist list"
pp PASS 'gh gist create notes.md' "secret gist (default)"
pp PASS 'gh gist create -d "help page" -f app.py app.py' "secret gist with description"
pp PASS 'gh gist view abc123' "gist view"
pp PASS 'gh api user/repos --paginate --jq ".[].name"' "api list repos"
pp PASS 'gh api user/repos -X GET -f per_page=100' "api list repos with GET fields"
pp PASS 'gh api user/repos -f name=tool -F private=true' "api create private repo"
pp PASS 'gh api repos/acme/tool --jq ".private"' "api read repo"
pp PASS 'gh api repos/acme/tool --jq ".[] | select(.private == false)"' "jq filter on private"
pp PASS 'gh api gists -f files[a.txt][content]=x' "api secret gist"
pp PASS 'curl -s https://api.github.com/user/repos' "curl list repos"
pp PASS $'curl -X POST https://api.github.com/user/repos -d \'{"name":"tool","private":true}\'' "curl create private repo"
pp PASS 'gh pr list --state open' "pr list"
pp PASS 'git push origin feature/x' "git push (documented, not blocked)"
pp PASS 'mkdir -p out && gh gist list' "mkdir -p next to gist list"
pp PASS 'echo highlight ghost' "unrelated text containing gh"

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
