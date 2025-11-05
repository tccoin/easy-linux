pip install websockify


tmux kill-session -t tunnel1
tmux kill-session -t tunnel2
tmux kill-session -t novnc1
tmux kill-session -t novnc2
tmux new-session -d -s tunnel1 'ssh -L 0.0.0.0:4910:lh1402.arc-ts.umich.edu:5910 lighthouse'
tmux new-session -d -s tunnel2 'ssh -L 0.0.0.0:4920:lh1402.arc-ts.umich.edu:5920 lighthouse'
tmux new-session -d -s novnc1 'novnc --vnc localhost:4910 --listen 4911'
tmux new-session -d -s novnc2 'novnc --vnc localhost:4920 --listen 4921'

nc localhost 4920
nmap -p 4920 localhost
sudo lsof -i :4920

tmux kill-session -t tunnel1_code
tmux new-session -d -s tunnel1_code 'ssh -L 0.0.0.0:4912:lh1402.arc-ts.umich.edu:4912 lighthouse'
tmux kill-session -t tunnel2_code
tmux new-session -d -s tunnel2_code 'ssh -L 0.0.0.0:4912:lh1402.arc-ts.umich.edu:4922 lighthouse'

vncserver :10 \
  -geometry 1920x1080 \
  -depth 24 \
  -fp catalogue:/etc/X11/fontpath.d \
  -xstartup ~/.vnc/xstartup \
  -deferupdate 1 \
  -dridir /usr/lib64/dri \
  -registrydir /usr/lib64/xorg

# 1400
vncserver :20 \
  -geometry 1920x1080 \
  -depth 24 \
  -fp catalogue:/etc/X11/fontpath.d \
  -xstartup ~/.vnc/xstartup \
  -deferupdate 1 \
  -dridir /usr/lib64/dri \
  -registrydir /usr/lib64/xorg


vncserver :30 \
  -geometry 1920x1080 \
  -depth 24 \
  -fp catalogue:/etc/X11/fontpath.d \
  -xstartup ~/.vnc/xstartup \
  -deferupdate 1 \
  -dridir /usr/lib64/dri \
  -registrydir /usr/lib64/xorg

vncserver -kill :10
vncserver -kill :20
vncserver -kill :30

wget https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64 | tar -zx -C ~/cursor

