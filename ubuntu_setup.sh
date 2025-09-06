#ssh
sudo apt update
sudo apt upgrade
sudo apt install ssh
sudo systemctl enable ssh

# docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world
sudo groupadd docker
sudo usermod -aG docker $USER

# nvidia-container-toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
sudo apt-get install -y \
    nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# zsh & tools
cd ~/Downloads/
git clone https://github.com/tccoin/easy-linux
cd easy-linux/
bash zsh.sh
sudo apt install -y tmux
chsh -s /usr/bin/zsh

# vnc
wget https://github.com/TurboVNC/turbovnc/releases/download/3.2/turbovnc_3.2_amd64.deb
sudo apt install dbus-x11
sudo dpkg -i turbovnc_3.2_amd64.deb
sudo snap install novnc

# sudo nano /etc/systemd/system/turbovnc@:2.service
cp vnc/turbovnc@:2.service /etc/systemd/system/
# replace USER with $USER
sudo sed -i "s/USER/$USER/g" /etc/systemd/system/turbovnc@:2.service
sudo systemctl daemon-reload
sudo systemctl enable turbovnc@:2.service --now
novnc --vnc localhost:5902

# conda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -u
rm Miniconda3-latest-Linux-x86_64.sh
conda init zsh

# install 7z
sudo apt-get install p7zip-full