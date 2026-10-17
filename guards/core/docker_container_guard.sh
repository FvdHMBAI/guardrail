#!/bin/bash
# GuardRail Core Guard: docker_container_guard
# Blocks `docker run` / `docker create` with flags that break container
# isolation: --privileged, host networking, host PID namespace, and
# bind-mounting the host root filesystem.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_docker_container_guard() {
  echo "$CMD_SHELL" | grep -qE '\bdocker[[:space:]]+(run|create)\b' || return 0

  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:]])--privileged\b'; then
    guardrail_audit "Docker-Guard" "Privileged container blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "DOCKER-GUARD: --privileged grants the container near-host-root capabilities and is a known container-escape vector. Run without --privileged, or add only the specific --cap-add needed."
    return
  fi

  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:]])--network[[:space:]=]*host\b'; then
    guardrail_audit "Docker-Guard" "Host network container blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "DOCKER-GUARD: --network host removes network isolation between the container and the host. Use a bridge network and publish only the ports you need (-p)."
    return
  fi

  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:]])--pid[[:space:]=]*host\b'; then
    guardrail_audit "Docker-Guard" "Host PID namespace container blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "DOCKER-GUARD: --pid host lets the container see and signal every process on the host. Run without --pid host."
    return
  fi

  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:]])(-v|--volume)[[:space:]=]+/:'; then
    guardrail_audit "Docker-Guard" "Host root mount blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "DOCKER-GUARD: mounting the host root filesystem (-v /:/host or similar) gives the container write access to the entire host. Mount only the specific directory the workload needs."
    return
  fi
}
