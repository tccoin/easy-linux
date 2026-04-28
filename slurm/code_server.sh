#!/usr/bin/env bash
set -euo pipefail

CODE_SERVER_BIN="${CODE_SERVER_BIN:-$HOME/tasks/code-server/bin/code-server}"
CODE_SERVER_PORT="${CODE_SERVER_PORT:-4912}"
CODE_SERVER_TMUX_SESSION="${CODE_SERVER_TMUX_SESSION:-code-server-${CODE_SERVER_PORT}}"
WORKDIR="${1:-$PWD}"

[[ -x "$CODE_SERVER_BIN" ]] || {
  echo "ERROR: code-server binary not found or not executable: $CODE_SERVER_BIN" >&2
  exit 1
}

if tmux has-session -t "$CODE_SERVER_TMUX_SESSION" >/dev/null 2>&1; then
  echo "code-server is already running in tmux session: $CODE_SERVER_TMUX_SESSION"
  echo "Attach with: tmux attach -t $CODE_SERVER_TMUX_SESSION"
  exit 0
fi

printf -v CODE_SERVER_CMD '%q ' \
  "$CODE_SERVER_BIN" \
  --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" \
  "$WORKDIR"

tmux new-session -d -s "$CODE_SERVER_TMUX_SESSION" -c "$WORKDIR" "exec ${CODE_SERVER_CMD}"
sleep 1

tmux has-session -t "$CODE_SERVER_TMUX_SESSION" >/dev/null 2>&1 || {
  echo "ERROR: failed to start tmux session $CODE_SERVER_TMUX_SESSION" >&2
  exit 1
}

echo "Started code-server in tmux session: $CODE_SERVER_TMUX_SESSION"
echo "URL: http://localhost:${CODE_SERVER_PORT}/"
echo "Working directory: $WORKDIR"
echo "Attach with: tmux attach -t $CODE_SERVER_TMUX_SESSION"
