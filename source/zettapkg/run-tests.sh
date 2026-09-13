#!/usr/bin/env bash
# Run every zettapkg ERT suite in batch, each under a real timeout.
#
#   source/zettapkg/run-tests.sh            # the time-management packages
#   source/zettapkg/run-tests.sh org-queue  # one package's suites
#
# The packages are listed in $pkgs; the older zettapkg suites need their
# own load paths and are not run here.
#
# Not `perl -e 'alarm N'`: Emacs installs its own SIGALRM handler, so an
# inherited alarm never kills a hung batch Emacs.  coreutils `timeout`
# with SIGKILL does; a killed suite is a failure, which is what a hang
# should be.

set -u
cd "$(dirname "$0")/../.." || exit 1
TIMEOUT=${TIMEOUT:-120}
pkgs=(source/zettapkg/org-queue source/zettapkg/org-gantt source/zettapkg/org-routine
      source/zettapkg/org-decorate source/zettapkg/org-chain source/zettapkg/org-knowledge)
loadpath=()
for p in "${pkgs[@]}"; do [ -d "$p" ] && loadpath+=(-L "$p"); done

status=0
if [ $# -gt 0 ]; then
  suites=(source/zettapkg/"$1"/test/*-test.el)
else
  suites=()
  for p in "${pkgs[@]}"; do [ -d "$p" ] && suites+=("$p"/test/*-test.el); done
fi
for suite in "${suites[@]}"; do
  [ -f "$suite" ] || continue
  name=$(basename "$suite" .el)
  log=$(mktemp -t "$name.XXXX")
  timeout -s KILL "$TIMEOUT" emacs -Q --batch "${loadpath[@]}" -l "$suite" \
    -f ert-run-tests-batch-and-exit >"$log" 2>&1
  rc=$?
  summary=$(grep -E '^Ran ' "$log" | tail -1)
  if [ "$rc" -ne 0 ] || [ -z "$summary" ]; then
    status=1
    printf '%-30s FAILED (rc %s)\n' "$name" "$rc"
    grep -E 'FAILED|condition:' -A 4 "$log" | head -40
  else
    printf '%-30s %s\n' "$name" "$summary"
  fi
  rm -f "$log"
done
exit $status
