# tmux kill-session -t tunnel1
# tmux kill-session -t tunnel2
# tmux kill-session -t novnc1
# tmux kill-session -t novnc2
# tmux new-session -d -s tunnel1 'ssh -L 0.0.0.0:4910:lh1400.arc-ts.umich.edu:5910 lighthouse'
# tmux new-session -d -s tunnel2 'ssh -L 0.0.0.0:4920:lh1400.arc-ts.umich.edu:5920 lighthouse'
# tmux new-session -d -s novnc1 'novnc --vnc localhost:4910 --listen 4911'
# tmux new-session -d -s novnc2 'novnc --vnc localhost:4920 --listen 4921'

# tmux kill-session -t tunnel1_code
# tmux new-session -d -s tunnel1_code 'ssh -L 0.0.0.0:4912:lh1400.arc-ts.umich.edu:4912 lighthouse'
# tmux kill-session -t tunnel2_code
# tmux new-session -d -s tunnel2_code 'ssh -L 0.0.0.0:4922:lh1400.arc-ts.umich.edu:4922 lighthouse'

tmux kill-session -t tunnel_lighthouse1
PORT_START=4910
PORTS=$(seq 2 9)
SSH_ARGS="-L 0.0.0.0:$PORT_START:lh1400.arc-ts.umich.edu:$(($PORT_START + 1000))"
for p in $PORTS; do
  # skip p==1 because it's used for novnc
  if [ $p -eq 1 ]; then
    continue
  fi
  PORT_NUM=$((PORT_START + p))
  echo "Forwarding port ${PORT_NUM}"
  SSH_ARGS="$SSH_ARGS -L 0.0.0.0:${PORT_NUM}:lh1400.arc-ts.umich.edu:${PORT_NUM}"
done
echo "ssh -N ${SSH_ARGS} lighthouse"
tmux new-session -d -s tunnel_lighthouse1 "ssh -N ${SSH_ARGS} lighthouse"

tmux kill-session -t tunnel_lighthouse2
PORT_START=4920
PORTS=$(seq 2 9)
SSH_ARGS="-L 0.0.0.0:$PORT_START:lh1400.arc-ts.umich.edu:$(($PORT_START + 1000))"
for p in $PORTS; do
  # skip p==1 because it's used for novnc
  if [ $p -eq 1 ]; then
    continue
  fi
  PORT_NUM=$((PORT_START + p))
  echo "Forwarding port ${PORT_NUM}"
  SSH_ARGS="$SSH_ARGS -L 0.0.0.0:${PORT_NUM}:lh1400.arc-ts.umich.edu:${PORT_NUM}"
done
echo "ssh -N ${SSH_ARGS} lighthouse"
tmux new-session -d -s tunnel_lighthouse2 "ssh -N ${SSH_ARGS} lighthouse"

tmux kill-session -t tunnel_lighthouse3
PORT_START=4930
PORTS=$(seq 2 9)
SSH_ARGS="-L 0.0.0.0:$PORT_START:lh1402.arc-ts.umich.edu:$(($PORT_START + 1000))"
for p in $PORTS; do
  # skip p==1 because it's used for novnc
  if [ $p -eq 1 ]; then
    continue
  fi
  PORT_NUM=$((PORT_START + p))
  echo "Forwarding port ${PORT_NUM}"
  SSH_ARGS="$SSH_ARGS -L 0.0.0.0:${PORT_NUM}:lh1402.arc-ts.umich.edu:${PORT_NUM}"
done
echo "ssh -N ${SSH_ARGS} lighthouse"
tmux new-session -d -s tunnel_lighthouse3 "ssh -N ${SSH_ARGS} lighthouse"

tmux kill-session -t novnc1
tmux kill-session -t novnc2
tmux kill-session -t novnc3
tmux new-session -d -s novnc1 'novnc --vnc localhost:4910 --listen 4911'
tmux new-session -d -s novnc2 'novnc --vnc localhost:4920 --listen 4921'
tmux new-session -d -s novnc3 'novnc --vnc localhost:4930 --listen 4931'