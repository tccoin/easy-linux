#!/usr/bin/env bash
set -euo pipefail

SELF="$(readlink -f "$0")"
HOST_SHORT="$(hostname -s)"
JOB_ID="${1:-}"
TARGET_NODE=""

SIF_PATH="/nfs/turbo/coe-junzhewu/navverse_mar24.sif"
DISPLAY_NUM=10
VNC_PORT=5910
CLOUDY_ALIAS="cloudy"
CLOUDY_TUNNEL_PORT=4910
CLOUDY_NOVNC_PORT=4911
CODE_SERVER_PORT=4912
CODE_SERVER_CLOUDY_TUNNEL_PORT_DEFAULT=14912
CODE_SERVER_CLOUDY_TUNNEL_PORT=""
VNC_PASSWD_FILE="$HOME/.vnc/navverse_mar24.passwd"
LOG_DIR="$HOME/tasks/logs"
SCRIPT_DIR="$HOME/tasks/scripts"
XSTARTUP_FILE="$SCRIPT_DIR/navverse_mar24_desktop_xstartup.sh"
CODE_SERVER_PROXY_SCRIPT="$SCRIPT_DIR/cloudy_tcp_proxy.py"
CODE_SERVER_PROXY_REMOTE_PATH="/tmp/${USER}-cloudy_tcp_proxy.py"
VNC_TMUX_SESSION="vnc-gl1800-10"
TUNNEL_TMUX_SESSION="rtun-cloudy-4910"
CLOUDY_TMUX_SESSION="novnc-gl1800-4911"
CODE_SERVER_TUNNEL_TMUX_SESSION="rtun-cloudy-4912"
CODE_SERVER_CLOUDY_PROXY_TMUX_SESSION="code-server-cloudy-4912"
RUN_LOG="$LOG_DIR/$(date +%Y%m%d_%H%M%S)_claw_vnc_cloudy_forward.log"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

is_login_node() {
  [[ "$HOST_SHORT" == gl-login* ]]
}

detect_running_job_id() {
  mapfile -t jobs < <(squeue -u "$USER" -h -t R -o '%i|%j|%N' 2>/dev/null)
  [[ ${#jobs[@]} -gt 0 ]] || fail "no running jobs found for $USER"
  if [[ ${#jobs[@]} -gt 1 ]]; then
    printf 'Multiple running jobs detected:\n' >&2
    printf '  %s\n' "${jobs[@]}" >&2
    fail "please pass the desired job id explicitly"
  fi
  echo "${jobs[0]%%|*}"
}

detect_job_node() {
  local job_id="$1"
  local node_list

  node_list="$(squeue -j "$job_id" -h -o '%N' 2>/dev/null | awk 'NF {print; exit}')"
  [[ -n "$node_list" ]] || fail "could not determine node for job $job_id"

  # Expand bracket syntax like gl[1234-1235] and use the first host.
  scontrol show hostnames "$node_list" 2>/dev/null | awk 'NF {print; exit}'
}

cloudy_port_is_free() {
  local port="$1"
  ssh "$CLOUDY_ALIAS" "test -z \"\$(ss -H -ltn '( sport = :$port )')\"" >/dev/null 2>&1
}

pick_cloudy_loopback_port() {
  local preferred_port="$1"
  local max_tries="${2:-50}"
  local port

  for ((port=preferred_port; port<preferred_port+max_tries; port++)); do
    if cloudy_port_is_free "$port"; then
      echo "$port"
      return 0
    fi
  done

  return 1
}

wait_for_cloudy_listener() {
  local port="$1"
  local label="$2"
  local attempt

  for attempt in {1..10}; do
    if ! cloudy_port_is_free "$port"; then
      return 0
    fi
    sleep 1
  done

  fail "$label did not start listening on $CLOUDY_ALIAS:$port"
}

ensure_local_tmux_session() {
  local session_name="$1"
  local label="$2"

  tmux has-session -t "$session_name" >/dev/null 2>&1 || fail "$label exited immediately; inspect tmux session $session_name"
}

ensure_cloudy_tmux_session() {
  local session_name="$1"
  local label="$2"

  ssh "$CLOUDY_ALIAS" "tmux has-session -t $session_name" >/dev/null 2>&1 || fail "$label exited immediately on $CLOUDY_ALIAS; inspect tmux session $session_name"
}

run_internal() {
  mkdir -p "$LOG_DIR" "$SCRIPT_DIR" "$HOME/.vnc"
  exec > >(tee -a "$RUN_LOG") 2>&1

  [[ "$HOME" != "/workspace" ]] || fail "run this script on the host shell, not inside the container"
  [[ -f "$VNC_PASSWD_FILE" ]] || fail "missing VNC password file: $VNC_PASSWD_FILE"

  CODE_SERVER_CLOUDY_TUNNEL_PORT="$(pick_cloudy_loopback_port "$CODE_SERVER_CLOUDY_TUNNEL_PORT_DEFAULT")" \
    || fail "could not find a free internal tunnel port on $CLOUDY_ALIAS starting from $CODE_SERVER_CLOUDY_TUNNEL_PORT_DEFAULT"
  cloudy_port_is_free "$CODE_SERVER_PORT" \
    || fail "$CLOUDY_ALIAS:$CODE_SERVER_PORT is already in use; stop the existing service or change CODE_SERVER_PORT"

  cat > "$XSTARTUP_FILE" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
unset WAYLAND_DISPLAY
export XDG_RUNTIME_DIR="/tmp/$USER-runtime-vnc-10"
export XDG_SESSION_TYPE="x11"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
if [ -x /usr/bin/dbus-launch ]; then
  DBUS_LAUNCH_BIN=/usr/bin/dbus-launch
elif command -v dbus-launch >/dev/null 2>&1; then
  DBUS_LAUNCH_BIN="$(command -v dbus-launch)"
else
  DBUS_LAUNCH_BIN=""
fi
xsetroot -solid '#1e1e1e'
xterm -geometry 120x36+20+20 -ls -title "host shell" &
if [ "${CLAW_VNC_START_CONTAINER_SHELL:-1}" = "1" ]; then
  xterm -geometry 120x36+80+80 -ls -title "NavVerse container shell" -e /home/junzhewu/tasks/scripts/claw-launch.sh /nfs/turbo/coe-junzhewu/navverse_mar24.sif bash &
fi
if [ "${CLAW_VNC_START_DESKTOP:-1}" = "1" ]; then
  if command -v gnome-session >/dev/null 2>&1 && [ -n "$DBUS_LAUNCH_BIN" ]; then
    "$DBUS_LAUNCH_BIN" --exit-with-session gnome-session >/tmp/navverse-vnc-desktop.log 2>&1 &
  elif command -v startxfce4 >/dev/null 2>&1 && [ -n "$DBUS_LAUNCH_BIN" ]; then
    "$DBUS_LAUNCH_BIN" --exit-with-session startxfce4 >/tmp/navverse-vnc-desktop.log 2>&1 &
  elif command -v xfce4-session >/dev/null 2>&1 && [ -n "$DBUS_LAUNCH_BIN" ]; then
    "$DBUS_LAUNCH_BIN" --exit-with-session xfce4-session >/tmp/navverse-vnc-desktop.log 2>&1 &
  fi
fi
exec xterm -geometry 120x36+40+40 -ls -title "VNC session shell"
EOF
  chmod 700 "$XSTARTUP_FILE"

  echo "=== stop previous sessions ==="
  tmux kill-session -t "$VNC_TMUX_SESSION" 2>/dev/null || true
  tmux kill-session -t "$TUNNEL_TMUX_SESSION" 2>/dev/null || true
  tmux kill-session -t "$CODE_SERVER_TUNNEL_TMUX_SESSION" 2>/dev/null || true
  /opt/TurboVNC/bin/vncserver -kill :$DISPLAY_NUM >/dev/null 2>&1 || true
  ssh "$CLOUDY_ALIAS" "tmux kill-session -t $CLOUDY_TMUX_SESSION 2>/dev/null || true" || true
  ssh "$CLOUDY_ALIAS" "tmux kill-session -t $CODE_SERVER_CLOUDY_PROXY_TMUX_SESSION 2>/dev/null || true" || true

  echo "=== start new sessions ==="
  tmux new-session -d -s "$VNC_TMUX_SESSION" "bash -lc '/opt/TurboVNC/bin/vncserver -fg :$DISPLAY_NUM -geometry 1920x1080 -depth 24 -localhost -rfbauth $VNC_PASSWD_FILE -xstartup $XSTARTUP_FILE'"
  sleep 5
  ensure_local_tmux_session "$VNC_TMUX_SESSION" "VNC server session"
  tmux new-session -d -s "$TUNNEL_TMUX_SESSION" "bash -lc 'ssh -N -o ExitOnForwardFailure=yes -R $CLOUDY_TUNNEL_PORT:localhost:$VNC_PORT $CLOUDY_ALIAS'"
  sleep 3
  ensure_local_tmux_session "$TUNNEL_TMUX_SESSION" "VNC reverse tunnel"
  wait_for_cloudy_listener "$CLOUDY_TUNNEL_PORT" "VNC reverse tunnel"
  ssh "$CLOUDY_ALIAS" "tmux new-session -d -s $CLOUDY_TMUX_SESSION 'bash -lc \"PATH=/snap/bin:\$PATH novnc --vnc localhost:$CLOUDY_TUNNEL_PORT --listen $CLOUDY_NOVNC_PORT\"'"
  sleep 3
  ensure_cloudy_tmux_session "$CLOUDY_TMUX_SESSION" "noVNC proxy"
  tmux new-session -d -s "$CODE_SERVER_TUNNEL_TMUX_SESSION" "bash -lc 'ssh -N -o ExitOnForwardFailure=yes -R $CODE_SERVER_CLOUDY_TUNNEL_PORT:localhost:$CODE_SERVER_PORT $CLOUDY_ALIAS'"
  sleep 3
  ensure_local_tmux_session "$CODE_SERVER_TUNNEL_TMUX_SESSION" "code-server reverse tunnel"
  wait_for_cloudy_listener "$CODE_SERVER_CLOUDY_TUNNEL_PORT" "code-server reverse tunnel"
  scp "$CODE_SERVER_PROXY_SCRIPT" "$CLOUDY_ALIAS:$CODE_SERVER_PROXY_REMOTE_PATH"
  ssh "$CLOUDY_ALIAS" "chmod 700 $CODE_SERVER_PROXY_REMOTE_PATH"
  ssh "$CLOUDY_ALIAS" "tmux new-session -d -s $CODE_SERVER_CLOUDY_PROXY_TMUX_SESSION 'bash -lc \"exec python3 $CODE_SERVER_PROXY_REMOTE_PATH --listen-host 0.0.0.0 --listen-port $CODE_SERVER_PORT --target-host 127.0.0.1 --target-port $CODE_SERVER_CLOUDY_TUNNEL_PORT\"'"
  sleep 3
  ensure_cloudy_tmux_session "$CODE_SERVER_CLOUDY_PROXY_TMUX_SESSION" "code-server public proxy"
  wait_for_cloudy_listener "$CODE_SERVER_PORT" "code-server public proxy"

  echo "=== local tmux ==="
  tmux ls || true
  echo
  echo "=== cloudy tmux ==="
  ssh "$CLOUDY_ALIAS" "tmux ls" || true
  echo
  echo "=== summary ==="
  echo "JOB_ID=${JOB_ID:-local}"
  echo "TARGET_NODE=${TARGET_NODE:-$HOST_SHORT}"
  echo "URL=http://curly-cloudy.engin.umich.edu:$CLOUDY_NOVNC_PORT/vnc.html"
  echo "CODE_SERVER_URL=http://curly-cloudy.engin.umich.edu:$CODE_SERVER_PORT/"
  echo "CODE_SERVER_CLOUDY_TUNNEL_PORT=$CODE_SERVER_CLOUDY_TUNNEL_PORT"
  echo "VNC_SESSION=$VNC_TMUX_SESSION"
  echo "TUNNEL_SESSION=$TUNNEL_TMUX_SESSION"
  echo "CLOUDY_SESSION=$CLOUDY_TMUX_SESSION"
  echo "CODE_SERVER_TUNNEL_SESSION=$CODE_SERVER_TUNNEL_TMUX_SESSION"
  echo "CODE_SERVER_CLOUDY_PROXY_SESSION=$CODE_SERVER_CLOUDY_PROXY_TMUX_SESSION"
  echo "START_CODE_SERVER_WITH=$SCRIPT_DIR/code_server.sh"
  echo "RUN_LOG=$RUN_LOG"
}

if [[ "${1:-}" == "_internal_start" ]]; then
  shift || true
  JOB_ID="${1:-}"
  TARGET_NODE="${2:-}"
  run_internal
  exit 0
fi

if is_login_node; then
  if [[ -z "$JOB_ID" ]]; then
    JOB_ID="$(detect_running_job_id)"
  fi
  TARGET_NODE="$(detect_job_node "$JOB_ID")"
  echo "Using job $JOB_ID on node $TARGET_NODE"
  cmd="$(printf '%q ' "$SELF" _internal_start "$JOB_ID" "$TARGET_NODE")"
  exec srun --jobid "$JOB_ID" --nodelist "$TARGET_NODE" --overlap bash -lc "$cmd"
fi

run_internal
