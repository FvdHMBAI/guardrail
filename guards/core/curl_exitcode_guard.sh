#!/bin/bash
# GuardRail Core Guard: curl_exitcode_guard
# Warns when a curl status code is chained with a fallback via ||.
# "curl -w '%{http_code}' ... || echo 000" prints "000000" on failure, because
# the partial value and the fallback are concatenated. A monitoring script
# comparing against "200" then reads a value that is neither a success nor a
# recognisable error, so the check silently passes.
# License: MIT
#
# Shared vars: $CMD
# Shared fns: warn()

hook_curl_exitcode_guard() {
  case "$CMD" in
    *curl*) ;;
    *) return 0 ;;
  esac

  # curl with -w http_code plus an || echo fallback
  if echo "$CMD" | grep -qP 'curl\s.*-w.*http_code.*\|\|.*echo'; then
    warn "CURL-EXITCODE: 'curl -w http_code || echo 000' concatenates the partial value with the fallback and yields '000000' on failure, which makes status checks blind. Better: HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' URL) and check the exit code separately."
  fi

  # curl with a hardcoded status code fallback
  if echo "$CMD" | grep -qP 'curl\s.*\|\|\s*echo\s+["\x27]?\d{3}'; then
    warn "CURL-FALLBACK: A hardcoded HTTP status as an || fallback masks real failures. Capture the code in a variable and check curl's exit code separately."
  fi

  # Piping a download into a shell executes partial content on a broken transfer
  if echo "$CMD" | grep -qP 'curl\s[^|]*\|\s*(sudo\s+)?(bash|sh|zsh)\b'; then
    warn "CURL-PIPE: Piping a download straight into a shell runs partial content if the transfer breaks mid-stream. Download to a file, inspect it, then run it."
  fi
}
