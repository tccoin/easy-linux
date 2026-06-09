#!/usr/bin/env bash
# AWS GPU instance setup: NVIDIA driver 580, CUDA 12.9, and Amazon DCV (NICE DCV).
# Tested on: Ubuntu 24.04 (noble), x86_64, g7e/g6/g5 instances with NVIDIA GPUs.
#
# Usage:
#   bash setup_aws.sh
# Run sections individually by copy/paste or by uncommenting only what you need.
# A REBOOT is required after the NVIDIA driver install before CUDA/DCV will work.

set -euxo pipefail

############################
# 0. Prereqs
############################
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential dkms linux-headers-$(uname -r) \
    wget curl gnupg ca-certificates

############################
# 1. Set ubuntu user password (used by DCV system auth)
############################
echo "ubuntu:ubuntu" | sudo chpasswd

############################
# 2. NVIDIA driver 580 + CUDA toolkit
############################
# Add NVIDIA's CUDA apt repository for Ubuntu 24.04 (provides CUDA toolkit).
cd /tmp
wget -nv https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Driver 580 (open kernel modules). Use Ubuntu's noble-updates package, not
# the NVIDIA CUDA repo — the 575.57.08 binaries there fail to build against
# kernels >= 6.17 (e.g. linux-aws 6.17.0-1012-aws).
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-driver-580-open

# CUDA toolkit 12.9 (driver 580 supports CUDA 12.9 and 13.x).
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit-12-9

# Add CUDA to PATH for all users (login shells via /etc/profile).
sudo tee /etc/profile.d/cuda.sh >/dev/null <<'EOF'
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF

# Also export from interactive non-login shells (VSCode terminals, tmux, etc.),
# which never source /etc/profile.d.
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    grep -qxF 'export PATH=/usr/local/cuda/bin:$PATH' "$rc" || \
        echo 'export PATH=/usr/local/cuda/bin:$PATH' >> "$rc"
    grep -qxF 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' "$rc" || \
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> "$rc"
done

# Disable the Nouveau kernel module (NVIDIA driver requires this).
echo -e "blacklist nouveau\noptions nouveau modeset=0" | \
    sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
sudo update-initramfs -u

# >>> REBOOT REQUIRED HERE <<<
# After reboot, verify with: nvidia-smi  and  nvcc --version

############################
# 3. Amazon DCV (NICE DCV) server 2025.0
############################
# Reference: https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-server.html
# Latest packages page: https://download.amazondcv.com/latest.html

# Desktop environment (DCV needs an X session). Lightweight option:
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ubuntu-desktop-minimal \
    mesa-utils \
    pulseaudio-utils

# Switch to multi-user (no GUI on console) so DCV virtual sessions own the GPU.
sudo systemctl set-default multi-user.target
sudo systemctl isolate multi-user.target || true

# Import the DCV GPG key.
cd /tmp
wget -nv https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
gpg --import NICE-GPG-KEY

# Download and extract Ubuntu 24.04 x86_64 server package (uses "latest" alias).
wget -nv https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2404-x86_64.tgz
tar -xzf nice-dcv-ubuntu2404-x86_64.tgz
cd nice-dcv-*-ubuntu2404-x86_64

# Install server, web viewer, and xdcv (virtual sessions).
sudo apt-get install -y \
    ./nice-dcv-server_*_amd64.ubuntu2404.deb \
    ./nice-dcv-web-viewer_*_amd64.ubuntu2404.deb \
    ./nice-xdcv_*_amd64.ubuntu2404.deb

# Allow the dcv user to access the GPU.
sudo usermod -aG video dcv

# Enable and start the DCV server.
sudo systemctl enable --now dcvserver

############################
# 4. DCV session (auto-start via systemd)
############################
# Install a systemd unit that creates a virtual DCV session at boot.
sudo tee /etc/systemd/system/dcv-session.service >/dev/null <<'EOF'
[Unit]
Description=DCV virtual session for ubuntu user
After=dcvserver.service
Requires=dcvserver.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/dcv create-session --owner ubuntu --type virtual ubuntu-session
ExecStop=/usr/bin/dcv close-session ubuntu-session

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now dcv-session.service || true
dcv list-sessions || true

# Login uses system auth: username "ubuntu", password "ubuntu" (set in section 1).

############################
# 4b. Export DISPLAY for shell sessions
############################
# So GUI clients launched from a terminal target the DCV virtual session.
grep -qxF 'export DISPLAY=:0' "$HOME/.bashrc" || echo 'export DISPLAY=:0' >> "$HOME/.bashrc"
grep -qxF 'export DISPLAY=:0' "$HOME/.zshrc"  || echo 'export DISPLAY=:0' >> "$HOME/.zshrc"

############################
# 5. Security group / firewall
############################
# Open TCP 8443 (DCV default) inbound to your IP in the EC2 security group.
# DCV also supports QUIC over UDP 8443 if enabled in /etc/dcv/dcv.conf.

############################
# 6. Verify
############################
# nvidia-smi
# nvcc --version
# sudo systemctl status dcvserver
# dcv list-sessions
# Connect from a browser:  https://<public-ip>:8443/
