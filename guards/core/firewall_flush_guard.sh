#!/bin/bash
# GuardRail Core Guard: firewall_flush_guard
# Blocks iptables flush, ufw disable, and nftables flush.
# License: MIT
#
# Shared vars: $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_firewall_flush_guard() {
  if echo "$CMD_SHELL" | grep -qE 'ip6?tables[[:space:]]+-F|ip6?tables[[:space:]]+--flush|ip6?tables[[:space:]]+-X|iptables-restore'; then
    deny "FIREWALL-GUARD: iptables/ip6tables -F/--flush/-X/iptables-restore flushes all firewall rules. Modify individual rules instead."
  fi

  if echo "$CMD_SHELL" | grep -qE 'ufw[[:space:]]+(disable|reset)'; then
    deny "FIREWALL-GUARD: ufw disable/reset disables the firewall. Blocked without admin approval."
  fi

  if echo "$CMD_SHELL" | grep -qE 'nft[[:space:]]+(flush|delete)[[:space:]]+(ruleset|table|chain)'; then
    deny "FIREWALL-GUARD: nft flush/delete ruleset/table/chain flushes firewall rules. Blocked."
  fi
}
