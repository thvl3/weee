## Phase 4: SSH Configuration and Login Test for swiftbroom

echo ""
echo "### 13. Configure SSHD for Domain Logins on swiftbroom ###"
echo "## Backing up /etc/ssh/sshd_config to /etc/ssh/sshd_config.bak"
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "## Displaying current SSHD config related to password/challenge-response auth:"
sudo grep -E "^(PasswordAuthentication|ChallengeResponseAuthentication)" /etc/ssh/sshd_config
echo "## Ensure 'PasswordAuthentication yes' and 'ChallengeResponseAuthentication yes' are set."
echo "## If they are 'no' or commented out, edit with 'sudo nano /etc/ssh/sshd_config' and set them to 'yes'."
# Example lines to ensure are active (uncommented and set to yes):
# PasswordAuthentication yes
# ChallengeResponseAuthentication yes
# SSSD typically integrates via PAM, so these allow PAM to handle the domain password.

echo ""
echo "### 14. Restart SSHD on swiftbroom ###"
sudo systemctl restart sshd
sudo systemctl status sshd

echo ""
echo "### 15. Perform SSH Login Test for swiftbroom ###"
echo "## From ANOTHER machine, attempt to SSH as taxman@REPO.INTERNAL@172.21.0.101"
echo "## Command: ssh taxman@REPO.INTERNAL@172.21.0.101"
echo "## You should be prompted for taxman@REPO.INTERNAL's password (Em0j!sp34k)."
echo "## Upon successful login, a home directory /home/taxman@repo.internal should be created if it wasn't already."
echo "## CAPTURE A SCREENSHOT of the successful SSH login for your report."
echo "## Type 'exit' to close the SSH session."

echo ""
echo "### Swiftbroom domain join and authentication setup COMPLETE. ###"
