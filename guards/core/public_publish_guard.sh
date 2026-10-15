#!/bin/bash
# GuardRail Core Guard: public_publish_guard
# Stops an agent from making code or data public on its own: creating a public
# GitHub repository or gist, or switching an existing repository to public.
# Background: an agent created a public repository by itself and pushed
# internal data into it. Making something public is a human decision.
# License: MIT
#
# Shared vars: $CMD
# Shared fns: deny(), guardrail_audit()
#
# Blocked (before the command runs):
#   gh repo create ... --public              gh repo create ... (no --private/--internal)
#   gh repo edit ... --visibility public     gh gist create ... --public / -p
#   gh api .../repos with private=false or visibility=public
#   gh api user/repos | orgs/X/repos (create) without an explicit private=true
#   gh api gists with public=true            gh api graphql createRepository/updateRepository PUBLIC
#   curl api.github.com/user/repos | /orgs/X/repos (create) without "private":true
#   curl api.github.com/gists with "public":true, curl api.github.com/repos/... with private:false
#   glab repo create ... --public
# Not blocked (documented, too many false alarms): git push to a remote that is
# already public, gh repo fork, gh release create.

_public_publish_deny() {
  local what="$1" how="$2"
  guardrail_audit "public_publish_guard" "$what" "$CMD" "blocked"
  deny "PUBLIC-PUBLISH-GUARD: Paused before ${what}. Making code or data public is a decision for a human, so GuardRail holds it here. Nothing has been created or changed. To go ahead safely: ${how} If it really should be public, a human can run the command on purpose, for example with a leading ! in the Claude Code prompt or in their own terminal."
}

hook_public_publish_guard() {
  # Fast exit: only GitHub/GitLab CLIs and the GitHub API are relevant.
  case "$CMD" in
    *gh*|*glab*|*github*|*GITHUB*|*GitHub*) ;;
    *) return 0 ;;
  esac

  # Normalise: join line continuations, turn newlines into separators,
  # drop quotes and backslashes, collapse whitespace.
  # Portable (BSD/macOS and GNU): bash parameter expansion instead of
  # sed N/\n, which BSD sed handles differently (it drops a single-line input).
  local n
  n=${CMD//$'\\\n'/ }
  n=$(printf '%s' "$n" | tr '\n\t' '; ' | tr -d "\"'\\\\\`" | tr -s ' ')
  # Subshell and brace characters become spaces; then split into simple
  # commands (one per line) on ; && || |
  n=$(printf '%s' "$n" | tr '(){}' '    ' | tr -s ' ')
  local segs
  segs=${n//&&/$'\n'}
  segs=${segs//||/$'\n'}
  segs=$(printf '%s' "$segs" | tr ';|' '\n\n')

  local gh_re='(^|[[:space:]/=$])gh[[:space:]]+'
  local seg

  # Variable indirection: VIS=--public; gh repo create x $VIS
  local whole_public=0
  printf '%s' "$n" | grep -qE '(^|[[:space:]=])--public([[:space:]=]|$)' && whole_public=1

  while IFS= read -r seg; do
    [ -z "$seg" ] && continue
    seg=" $seg "

    # --- gh repo create ---
    if printf '%s' "$seg" | grep -qE "${gh_re}repo[[:space:]]+create([[:space:]]|$)"; then
      if printf '%s' "$seg" | grep -qiE '[[:space:]]--public(=true)?[[:space:]]|--visibility[[:space:]=]+public' || [ "$whole_public" = 1 ]; then
        _public_publish_deny "creating a public GitHub repository" \
          "create it with --private (gh repo create NAME --private), push and review what is in it, and only then change the visibility."
        return 0
      fi
      if ! printf '%s' "$seg" | grep -qE '[[:space:]]--(private|internal)(=true)?[[:space:]]'; then
        _public_publish_deny "creating a GitHub repository without an explicit visibility" \
          "add --private (or --internal for organisation repos) so the visibility is clear before anything is pushed."
        return 0
      fi
    fi

    # --- gh repo edit --visibility public ---
    if printf '%s' "$seg" | grep -qE "${gh_re}repo[[:space:]]+edit([[:space:]]|$)" \
       && printf '%s' "$seg" | grep -qE '[[:space:]]--visibility([[:space:]=]|$)'; then
      if ! printf '%s' "$seg" | grep -qiE '[[:space:]]--visibility[[:space:]=]+(private|internal)[[:space:]]'; then
        _public_publish_deny "switching a GitHub repository to public" \
          "check the full history for secrets and internal data first (for example with gitleaks), and keep the repository private until that review is done."
        return 0
      fi
    fi

    # --- gh gist create --public / -p ---
    if printf '%s' "$seg" | grep -qE "${gh_re}gist[[:space:]]+(create|new)([[:space:]]|$)"; then
      if printf '%s' "$seg" | grep -qE '[[:space:]](--public(=true)?|-[A-Za-z]*p[A-Za-z]*)[[:space:]]' || [ "$whole_public" = 1 ]; then
        _public_publish_deny "creating a public gist" \
          "leave out --public/-p; gh creates secret gists by default."
        return 0
      fi
    fi

    # --- glab repo create --public ---
    if printf '%s' "$seg" | grep -qE '(^|[[:space:]/])glab[[:space:]]+repo[[:space:]]+(create|new)([[:space:]]|$)' \
       && printf '%s' "$seg" | grep -qiE '[[:space:]]--public(=true)?[[:space:]]|--visibility[[:space:]=]+public'; then
      _public_publish_deny "creating a public GitLab project" \
        "create it with --private, review the content, and only then change the visibility."
      return 0
    fi

    # --- gh api / curl against the GitHub API ---
    local is_gh_api=0 is_curl_gh=0
    printf '%s' "$seg" | grep -qE "${gh_re}api[[:space:]]" && is_gh_api=1
    printf '%s' "$seg" | grep -qiE '(^|[[:space:]/])(curl|wget|http|xh)[[:space:]].*api\.github\.com' && is_curl_gh=1
    [ "$is_gh_api" = 0 ] && [ "$is_curl_gh" = 0 ] && continue

    # Request bodies can arrive through a pipe or heredoc (other segments),
    # so the body checks below look at the whole normalised command.
    # Visibility flipped to public on any repository endpoint, REST or GraphQL
    if printf '%s' "$n" | grep -qiE '(^|[^a-z_])private[[:space:]]*[:=][[:space:]]*false|visibility[[:space:]]*[:=][[:space:]]*public'; then
      _public_publish_deny "making a GitHub repository public through the API" \
        "keep private=true, review the repository content, and change the visibility deliberately afterwards."
      return 0
    fi

    # Visibility taken from a variable cannot be checked before it runs
    if printf '%s' "$n" | grep -qiE '(^|[^a-z_])(private|visibility|public)[[:space:]]*[:=][[:space:]]*\$'; then
      _public_publish_deny "changing repository or gist visibility to a value that is only known at run time" \
        "write the visibility literally (private=true or visibility=private) so it can be checked."
      return 0
    fi

    # Public gist through the API
    if printf '%s' "$seg" | grep -qiE '(^|[[:space:]/])gists([[:space:]/?]|$)' \
       && printf '%s' "$n" | grep -qiE '(^|[^a-z_])public[[:space:]]*[:=][[:space:]]*true'; then
      _public_publish_deny "creating a public gist through the API" \
        "send public=false (the default) so the gist stays secret."
      return 0
    fi

    # Repository creation through the API. GitHub creates PUBLIC repositories
    # when "private" is not sent, so an explicit private=true is required.
    if printf '%s' "$seg" | grep -qiE '(^|[[:space:]/])(user|orgs/[^[:space:]/]+)/repos([[:space:]?]|$)'; then
      local writes=0
      if [ "$is_gh_api" = 1 ]; then
        # gh api switches to POST as soon as fields or input are given
        printf '%s' "$seg" | grep -qE '[[:space:]](-f|-F|--field|--raw-field|--input)([[:space:]=]|$)|[[:space:]]-[fF][^[:space:]]' && writes=1
        printf '%s' "$seg" | grep -qiE '(-X|--method)[[:space:]=]*(POST|PUT)' && writes=1
        printf '%s' "$seg" | grep -qiE '(-X|--method)[[:space:]=]*GET' && writes=0
      else
        printf '%s' "$seg" | grep -qE '[[:space:]](-d|--data[a-z-]*|--json|-F|--form)([[:space:]=]|$)|[[:space:]]-d[^[:space:]]' && writes=1
        printf '%s' "$seg" | grep -qiE '(-X|--request)[[:space:]=]*(POST|PUT)' && writes=1
        printf '%s' "$seg" | grep -qiE '(-X|--request)[[:space:]=]*GET' && writes=0
      fi
      if [ "$writes" = 1 ] && ! printf '%s' "$n" | grep -qiE '(^|[^a-z_])private[[:space:]]*[:=][[:space:]]*true|visibility[[:space:]]*[:=][[:space:]]*(private|internal)'; then
        _public_publish_deny "creating a GitHub repository through the API without private=true (GitHub makes it public by default)" \
          "send private=true explicitly (gh api user/repos -f name=NAME -F private=true)."
        return 0
      fi
    fi
  done <<< "$segs"
  return 0
}
