#!/bin/bash
# GuardRail Pro: EU AI Act Article Mapping
# Maps guard categories to EU AI Act articles for compliance reporting.
# License: Proprietary (GuardRail Pro)

declare -A EU_AI_ACT_MAPPING=(
  ["PII-Shield"]="Art. 10 Data Governance|Prevents personal data exposure in AI agent outputs"
  ["PII-Gate"]="Art. 10 Data Governance|Blocks commands that dump environment variables or secrets"
  ["Secret-Detector"]="Art. 15 Accuracy, Robustness, Cybersecurity|Prevents credential and API key leaks"
  ["Main-Push-Guard"]="Art. 14 Human Oversight|Requires review before changes reach production"
  ["Force-Push-Guard"]="Art. 14 Human Oversight|Prevents irreversible overwrites of shared history"
  ["Git-Safety-Guard"]="Art. 14 Human Oversight|Blocks destructive git operations (reset --hard, clean -f)"
  ["Injection-Scanner"]="Art. 15 Accuracy, Robustness, Cybersecurity|Detects prompt injection and payload hiding"
  ["Destructive-Path"]="Art. 15 Accuracy, Robustness, Cybersecurity|Prevents deletion of critical system paths"
  ["Service-Protection"]="Art. 15 Accuracy, Robustness, Cybersecurity|Blocks stopping of critical services"
  ["Firewall-Guard"]="Art. 15 Accuracy, Robustness, Cybersecurity|Prevents firewall rule flushing"
  ["Mass-Update"]="Art. 14 Human Oversight|Blocks unscoped UPDATE/DELETE without WHERE clause"
  ["Env-Dump"]="Art. 10 Data Governance|Detects bulk secret exposure in command output"
  ["Error-Swallow"]="Art. 12 Record-keeping|Flags empty catch blocks that hide errors"
  ["Audit-Trail"]="Art. 12 Record-keeping|Logs all AI agent actions with timestamps and context"
  ["Deploy-Branch"]="Art. 14 Human Oversight|Enforces branch-to-environment mapping"
  ["Quality-Gate"]="Art. 15 Accuracy, Robustness, Cybersecurity|Multi-stage quality checks before deployment"
  ["Tabu-Gate"]="Art. 14 Human Oversight|Blocks access to protected database tables and auth systems"
  ["Self-Bypass"]="Art. 14 Human Oversight|Prevents AI agents from disabling their own safety controls"
  ["Script-Content"]="Art. 15 Accuracy, Robustness, Cybersecurity|Scans scripts for hidden malicious payloads"
  ["Gate-File"]="Art. 14 Human Oversight|Gate file workflow with anti-tampering protection"
)

declare -A EU_AI_ACT_ARTICLES=(
  ["Art. 9"]="Risk Management System|Ongoing risk identification and mitigation throughout the AI lifecycle"
  ["Art. 10"]="Data Governance|Quality criteria for training and operational data, bias detection"
  ["Art. 12"]="Record-keeping|Automatic logging of events for traceability and audit"
  ["Art. 14"]="Human Oversight|Measures enabling human oversight of AI system operation"
  ["Art. 15"]="Accuracy, Robustness, Cybersecurity|Resilience against errors, faults, and adversarial attacks"
)

_guardrail_get_article() {
  local guard="$1"
  local mapping="${EU_AI_ACT_MAPPING[$guard]:-}"
  if [ -n "$mapping" ]; then
    echo "$mapping" | cut -d'|' -f1
  else
    echo "Unmapped"
  fi
}

_guardrail_get_article_desc() {
  local guard="$1"
  local mapping="${EU_AI_ACT_MAPPING[$guard]:-}"
  if [ -n "$mapping" ]; then
    echo "$mapping" | cut -d'|' -f2
  fi
}
