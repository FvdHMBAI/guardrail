#!/bin/bash
# Guard: self_correction_loop
# Post-execution guard that detects errors in command output and forces
# the agent into a correction loop instead of silently continuing.
#
# Recognizes: build failures, test failures, runtime errors (TypeError,
# SyntaxError, ENOENT, etc). Ignores "0 errors", "passed", "success".
# License: MIT

hook_self_correction_loop() {
  local out="${OUTPUT:-}"
  [ -z "$out" ] && return 0

  local head_out
  head_out=$(printf '%s' "$out" | head -20)

  # Success patterns: not an error
  printf '%s' "$head_out" | grep -qiE '(0 errors|no errors|succeeded|success|passed|PASS)' && return 0

  # Build errors
  if printf '%s' "$head_out" | grep -qiE '(build failed|compilation error|tsc.*error|error TS[0-9]{3,}|next build.*error|webpack.*error)'; then
    add_context "BUILD ERROR detected. Self-correction required: read the error, open the file, apply the fix, rebuild. Do not continue without a green build."
    guardrail_audit "self_correction_loop" "build error" "$CMD" "correction-required"
    return 0
  fi

  # Test failures
  if printf '%s' "$head_out" | grep -qiE '(test.*fail|FAIL.*test|expect.*received|assertion.*error|vitest.*fail|jest.*fail)'; then
    add_context "TEST FAILURE detected. Self-correction required: analyze the failing test, fix the code or test, re-run. Do not skip failing tests."
    guardrail_audit "self_correction_loop" "test failure" "$CMD" "correction-required"
    return 0
  fi

  # Runtime errors
  if printf '%s' "$head_out" | grep -qiE '(TypeError|SyntaxError|ReferenceError|Cannot find module|ENOENT|EACCES|Permission denied|ERR!|FATAL|panic|segfault)'; then
    add_context "RUNTIME ERROR detected. Self-correction required: analyze the error, find root cause, fix, re-test. Do not work around errors."
    guardrail_audit "self_correction_loop" "runtime error" "$CMD" "correction-required"
    return 0
  fi

  return 0
}
