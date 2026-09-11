#!/usr/bin/env bash
# ui-test.sh -- exercise experimental tab-bar / header-line renderers in a
# THROWAWAY Emacs daemon, so a redisplay deadlock can never freeze your real
# session. Starts `emacs -Q --fg-daemon=zt-ui-test` with tools/ui-isolated-test.el,
# creates a GUI frame, and runs a *timed* redisplay. If redisplay returns, the
# renderer is freeze-safe; if it times out, only this throwaway daemon is stuck.
#
# Usage:
#   tools/ui-test.sh run     # start daemon, load harness, timed redisplay check
#   tools/ui-test.sh frame   # pop a GUI frame on the test daemon (visual check)
#   tools/ui-test.sh eval 'ELISP'   # eval in the test daemon (timed)
#   tools/ui-test.sh kill    # kill the throwaway daemon
#
# The real session is never named here; this only ever touches `zt-ui-test`.

set -uo pipefail

EMACS="${EMACS:-/opt/homebrew/bin/emacs}"
EMACSCLIENT="${EMACSCLIENT:-/opt/homebrew/bin/emacsclient}"
SERVER="zt-ui-test"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/tools/ui-isolated-test.el"
TIMEOUT="${TIMEOUT:-12}"

daemon_running() { "$EMACSCLIENT" -s "$SERVER" --eval '(emacs-pid)' >/dev/null 2>&1; }

cmd_kill() {
  pkill -f "fg-daemon=$SERVER" 2>/dev/null && echo "killed throwaway daemon '$SERVER'" \
    || echo "no '$SERVER' daemon running"
}

cmd_run() {
  cmd_kill
  echo "starting throwaway daemon '$SERVER' (emacs -Q, harness loaded)..."
  "$EMACS" -Q --fg-daemon="$SERVER" -l "$HARNESS" >/tmp/${SERVER}.log 2>&1 &
  for _ in $(seq 1 50); do daemon_running && break; sleep 0.2; done
  if ! daemon_running; then echo "FAILED to start; see /tmp/${SERVER}.log"; tail -20 /tmp/${SERVER}.log; return 1; fi
  echo "daemon up. creating a frame + timed redisplay (${TIMEOUT}s)..."
  # Make a GUI frame, then force an actual redisplay of the SVG tab bar.
  timeout "$TIMEOUT" "$EMACSCLIENT" -s "$SERVER" -c -e \
    '(progn (redisplay t) (format "REDISPLAY-OK; tab-bar-format=%S" tab-bar-format))'
  local rc=$?
  if [ $rc -eq 124 ]; then
    echo ">>> TIMED OUT -- the renderer deadlocked redisplay (FROZEN). Run: tools/ui-test.sh kill"
  elif [ $rc -ne 0 ]; then
    echo ">>> emacsclient exited $rc (see /tmp/${SERVER}.log)"
  else
    echo ">>> SAFE: redisplay completed without freezing."
    echo "    Inspect visually with: tools/ui-test.sh frame"
    echo "    When done:             tools/ui-test.sh kill"
  fi
}

cmd_frame() { daemon_running || { echo "no '$SERVER' daemon; run: tools/ui-test.sh run"; return 1; }
  "$EMACSCLIENT" -s "$SERVER" -c & echo "frame requested on '$SERVER'"; }

cmd_eval() { daemon_running || { echo "no '$SERVER' daemon; run: tools/ui-test.sh run"; return 1; }
  timeout "$TIMEOUT" "$EMACSCLIENT" -s "$SERVER" --eval "$1"; }

case "${1:-run}" in
  run)   cmd_run ;;
  frame) cmd_frame ;;
  eval)  shift; cmd_eval "${1:?need elisp}" ;;
  kill)  cmd_kill ;;
  *) echo "usage: $0 {run|frame|eval ELISP|kill}"; exit 1 ;;
esac
