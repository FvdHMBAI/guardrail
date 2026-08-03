#!/bin/bash
# GuardRail Demo Recording Script
# Simulates an AI agent hitting guards, with realistic timing.
# Usage: asciinema rec --command "bash demo/record-demo.sh" demo.cast

set -e

G=$'\033[0;32m' R=$'\033[0;31m' Y=$'\033[0;33m' B=$'\033[1m' D=$'\033[2m' Z=$'\033[0m' C=$'\033[0;36m'

DISPATCHER="/root/guardrail-product-rework/dispatchers/pre-bash.sh"

type_cmd() {
  local cmd="$1"
  printf "${D}\$ ${Z}"
  for ((i=0; i<${#cmd}; i++)); do
    printf "%s" "${cmd:$i:1}"
    sleep 0.04
  done
  echo ""
}

run_guard() {
  local cmd="$1"
  local result
  result=$(printf '{"session_id":"demo","tool_input":{"command":"%s"}}' "$cmd" | bash "$DISPATCHER" 2>/dev/null)
  local decision
  decision=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecision // "error"')
  local reason
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' | head -1)

  if [ "$decision" = "deny" ]; then
    echo ""
    echo "  ${R}BLOCKED${Z}  $reason"
    echo ""
  else
    echo "  ${G}ALLOWED${Z}"
    echo ""
  fi
}

clear
echo ""
echo "  ${B}GuardRail${Z} ${D}v0.3.0${Z}"
echo "  ${D}Pre-execution security for AI coding agents${Z}"
echo ""
sleep 1.5

echo "  ${C}--- Agent tries dangerous commands ---${Z}"
echo ""
sleep 0.8

type_cmd "rm -rf /home/developer/project"
sleep 0.3
run_guard "rm -rf /home/developer/project"
sleep 1.2

type_cmd "git push --force origin main"
sleep 0.3
run_guard "git push --force origin main"
sleep 1.2

type_cmd "DELETE FROM profiles WHERE 1=1;"
sleep 0.3
run_guard "psql -c \"DELETE FROM profiles WHERE 1=1;\""
sleep 1.2

echo "  ${C}--- Agent runs safe commands ---${Z}"
echo ""
sleep 0.8

type_cmd "npm test"
sleep 0.3
run_guard "npm test"
sleep 0.8

type_cmd "git push origin feature/my-branch"
sleep 0.3
run_guard "git push origin feature/my-branch"
sleep 1.0

echo "  ${C}--- Status ---${Z}"
echo ""
sleep 0.5

type_cmd "guardrail status"
sleep 0.3
echo ""
echo "  ${B}GuardRail${Z} ${D}v0.3.0${Z}"
echo ""
echo "  ${G}18${Z} core guards active"
echo "  ${G}Enforcement verified${Z} (registered hook and deny probe)"
echo "  ${D}0${Z} pro guards ${D}(guardrail upgrade --key ...)${Z}"
echo ""
echo "  ${D}Audit:${Z} ${B}3${Z} blocked / 5 total"
echo ""
echo "  ${D}Recent:${Z}"
echo "  ${R}x${Z} rm -rf /home/developer/project"
echo "  ${R}x${Z} git push --force origin main"
echo "  ${R}x${Z} DELETE FROM profiles WHERE 1=1"
echo "  ${G}+${Z} npm test"
echo "  ${G}+${Z} git push origin feature/my-branch"
echo ""
sleep 2

echo "  ${G}${B}One command to install:${Z}  npx guardrail-agent init"
echo ""
sleep 3
