#!/bin/bash
# keep_awake.sh — disable lid-close suspend on Linux (systemd)

set -e

CONF_FILE="/etc/systemd/logind.conf"
BACKUP_FILE="/etc/systemd/logind.conf.bak"

# Backup original config
if [ ! -f "$BACKUP_FILE" ]; then
    sudo cp "$CONF_FILE" "$BACKUP_FILE"
    echo "Backup created at $BACKUP_FILE"
fi

# Replace or add HandleLidSwitch=ignore
if grep -q "^HandleLidSwitch=" "$CONF_FILE"; then
    sudo sed -i 's/^HandleLidSwitch=.*/HandleLidSwitch=ignore/' "$CONF_FILE"
else
    echo "HandleLidSwitch=ignore" | sudo tee -a "$CONF_FILE" > /dev/null
fi

# Restart systemd-logind to apply changes
sudo systemctl restart systemd-logind

echo "✔ Lid close action set to 'ignore'. Your laptop will stay awake when lid is closed."