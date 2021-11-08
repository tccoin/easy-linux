sudo pacman -S openssh
sudo systemctl status sshd.service
# sudo nano /etc/ssh/sshd_config
sudo systemctl enable sshd.service
sudo systemctl start sshd.service

sudo pacman -S nss-mdns