#!/bin/bash

# Script to create user semibot and set up SSH key authentication

USERNAME="semibot"
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+m1Zervr1CehWrwyzkERtF08F85w5w90ENlek26HuzAEV8+SLtGXifrhbBMQ87wevBh+OG9PK8RJOKshqVUO2XdjBaOEj82JbcT69V/DTT8aKiDNQ3pt75FgyT5OGRkia44vnutAgAbRoQJezb/L4qau/IFCke1b3ClCeVJB31AvtMQ1p897J5wP4kVSQTAm/1PvinRj63pTHaLlTqCbLboQrpdgDPJRwpQn33bGQoO5iyy5b26gK/PKHT+tHxJPLjxvJw1OJ018i77PSrVDs+/ozhyzgfRrAJNAHgYsL7i7Mj/SOrlJO8+VkBszqDt3+wV2nLsFN/f6dGpi9sD2ijCbR9IRAlXjmYUEhTN7rtRDMsUZfybE4yWepfb2/xFgt9QQ1U9Ay1yl4XrFDOqYQkXuiQFG7P0V+unvMN4jUe+HDykinw0ZyT9IGVpDwlJHh8CoyXGK8X4UzpKr82n8TZgpWgzqIY1o0fyNbDfpep0QWuSd+wdVKPjMWye1PPq0= semibot@repo.internal"
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS_FILE="$SSH_DIR/authorized_keys"

# Create user if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    echo "Creating user $USERNAME..."
    sudo useradd -m -s /bin/bash "$USERNAME"
    if [ $? -ne 0 ]; then
        echo "Failed to create user $USERNAME. Exiting."
        exit 1
    fi
else
    echo "User $USERNAME already exists."
fi

# Create .ssh directory
echo "Creating $SSH_DIR..."
sudo mkdir -p "$SSH_DIR"
sudo chown "$USERNAME":"$USERNAME" "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"

# Add public key to authorized_keys
echo "Adding public key to $AUTHORIZED_KEYS_FILE..."
echo "$PUBLIC_KEY" | sudo tee "$AUTHORIZED_KEYS_FILE" > /dev/null
sudo chown "$USERNAME":"$USERNAME" "$AUTHORIZED_KEYS_FILE"
sudo chmod 600 "$AUTHORIZED_KEYS_FILE"

# Ensure SSH configuration is correct for key-based authentication
# This typically involves ensuring PubkeyAuthentication is yes and PasswordAuthentication is no in /etc/ssh/sshd_config
# For a specific user, we can add a Match User block

SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

# Check if a Match User block for semibot already exists
if sudo grep -q "Match User $USERNAME" "$SSHD_CONFIG_FILE"; then
    echo "Match User $USERNAME block already exists in $SSHD_CONFIG_FILE."
else
    echo "Adding Match User block for $USERNAME to $SSHD_CONFIG_FILE..."
    sudo bash -c "cat >> $SSHD_CONFIG_FILE" <<EOL

Match User $USERNAME
    PasswordAuthentication no
    PubkeyAuthentication yes
    AuthorizedKeysFile $AUTHORIZED_KEYS_FILE
EOL
    if [ $? -ne 0 ]; then
        echo "Failed to update $SSHD_CONFIG_FILE. Exiting."
        exit 1
    fi
    echo "Restarting SSH service..."
    sudo systemctl restart sshd
    if [ $? -ne 0 ]; then
        echo "Failed to restart SSH service. Please do it manually."
    fi
fi

echo "User $USERNAME setup complete. SSH key authentication should be configured."
echo "Make sure the user $USERNAME exists on the Active Directory domain REPO.INTERNAL and has the necessary permissions." 
