#!/bin/bash

# Script to join an AlmaLinux machine (mcjannek) to REPO.INTERNAL Active Directory Domain
# Run this script with sudo: sudo ./domainjoin_mcjannek.sh

# Stop on any error
set -e

DOMAIN_CONTROLLER_IP="172.21.0.103"
DOMAIN_CONTROLLER_HOSTNAME="headman.repo.internal"
DOMAIN_NAME="repo.internal"
REALM_NAME="REPO.INTERNAL"
DOMAIN_USER_FOR_JOIN="taxman@REPO.INTERNAL"
DOMAIN_USER_PASSWORD_HINT="W3L0v3R3p0" # Updated Password Hint
DOMAIN_SECONDARY_DNS_FALLBACK="1.1.1.1" # Define a fallback DNS
# The password for taxman@REPO.INTERNAL is now hinted as W3L0v3R3p0 - you will be prompted for this.

echo ">>> Starting Domain Join Process for mcjannek ($DOMAIN_NAME) <<<"

# --- Phase 1: Prerequisites (DNS, Time, Packages) ---
echo ""
echo "--- Phase 1: Prerequisites ---"

echo ""
echo "### 1. Configure DNS for mcjannek ###"
echo "## Attempting to set DNS via NetworkManager (nmcli)"
echo "## This assumes your primary active connection should use this DNS."
echo "## Find active connection:"
ACTIVE_CONNECTION_NAME=$(nmcli -t -f NAME connection show --active | head -n1)
ACTIVE_CONNECTION_UUID=$(nmcli -t -f UUID connection show --active | head -n1)

if [ -n "$ACTIVE_CONNECTION_UUID" ]; then
    echo "## Active connection found: Name='$ACTIVE_CONNECTION_NAME', UUID='$ACTIVE_CONNECTION_UUID'"
    echo "## Setting DNS to $DOMAIN_CONTROLLER_IP and fallback $DOMAIN_SECONDARY_DNS_FALLBACK for $ACTIVE_CONNECTION_NAME"
    
    # Modify DNS settings
    nmcli con mod "$ACTIVE_CONNECTION_UUID" ipv4.dns "$DOMAIN_CONTROLLER_IP,$DOMAIN_SECONDARY_DNS_FALLBACK"
    # Tell NetworkManager to not get DNS from DHCP
    nmcli con mod "$ACTIVE_CONNECTION_UUID" ipv4.ignore-auto-dns yes
    
    echo "## Applying changes by reactivating the connection..."
    # Reactivate the connection
    if nmcli con down "$ACTIVE_CONNECTION_UUID" && nmcli con up "$ACTIVE_CONNECTION_UUID"; then
        echo "## Connection reactivated successfully."
    else
        echo "## Failed to reactivate connection. Check NetworkManager status and logs."
        # As a fallback, try to ensure NetworkManager reloads connections if up/down fails
        nmcli c reload || echo "## Failed to reload connections."
        nmcli n on || echo "## Failed to turn networking on."
    fi
    
    sleep 5 # Give NetworkManager a moment
    echo "## Verifying /etc/resolv.conf (should reflect new DNS)"
    cat /etc/resolv.conf
else
    echo "## No active NetworkManager connection found. Attempting to manually set /etc/resolv.conf"
    echo "## Backing up /etc/resolv.conf to /etc/resolv.conf.bak"
    cp /etc/resolv.conf /etc/resolv.conf.bak || true
    echo "nameserver $DOMAIN_CONTROLLER_IP" > /etc/resolv.conf
    echo "nameserver $DOMAIN_SECONDARY_DNS_FALLBACK" >> /etc/resolv.conf # Fallback DNS
    echo "## Displaying new /etc/resolv.conf"
    cat /etc/resolv.conf
fi
echo "## Testing DNS resolution for the DC:"
ping -c 3 $DOMAIN_CONTROLLER_HOSTNAME
ping -c 3 $DOMAIN_NAME

echo ""
echo "### 2. Install and Configure Time Synchronization (chrony) for mcjannek ###"
dnf install chrony -y
echo "## Backing up /etc/chrony.conf to /etc/chrony.conf.bak"
cp /etc/chrony.conf /etc/chrony.conf.bak
echo "## Configuring chrony to use $DOMAIN_CONTROLLER_HOSTNAME as NTP source"
# Remove existing server/pool lines first
sed -i '/^server /d' /etc/chrony.conf
sed -i '/^pool /d' /etc/chrony.conf
echo "server $DOMAIN_CONTROLLER_HOSTNAME iburst" >> /etc/chrony.conf
echo "pool 2.almalinux.pool.ntp.org iburst" >> /etc/chrony.conf # Fallback
systemctl enable --now chronyd
echo "## Waiting a few seconds for chrony to sync..."
sleep 10
echo "## Checking chrony sources and sync status"
chronyc sources
chronyc tracking

echo ""
echo "### 3. Install Required Packages for AD Integration on mcjannek ###"
dnf install realmd sssd oddjob oddjob-mkhomedir samba-common-tools krb5-workstation adcli -y
echo "## During krb5-workstation installation, if prompted for Kerberos default realm, enter: $REALM_NAME"

echo ""
echo "--- Phase 1 for mcjannek complete. Review output carefully. ---"
echo "--- Ensure DNS resolves $DOMAIN_CONTROLLER_HOSTNAME and time is synchronizing. ---"

# --- Phase 2: Discover and Join Domain ---
echo ""
echo "--- Phase 2: Discover and Join Domain ---"

echo ""
echo "### 4. Create a clean /etc/krb5.conf ###"
echo "## Backing up existing /etc/krb5.conf to /etc/krb5.conf.orig-scriptbkp"
mv /etc/krb5.conf /etc/krb5.conf.orig-scriptbkp || true # Continue if it doesn't exist
echo "## Creating new minimal /etc/krb5.conf"
cat << EOF > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = $REALM_NAME
 #default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 $REALM_NAME = {
  kdc = $DOMAIN_CONTROLLER_HOSTNAME
  admin_server = $DOMAIN_CONTROLLER_HOSTNAME
 }

[domain_realm]
 .$DOMAIN_NAME = $REALM_NAME
 $DOMAIN_NAME = $REALM_NAME
EOF

echo "## New /etc/krb5.conf created:"
cat /etc/krb5.conf

echo ""
echo "### 5. Clear existing Kerberos tickets (if any) ###"
kdestroy -A || echo "## No tickets to destroy or kdestroy not critical if it fails here."

echo ""
echo "### 6. Discover the $REALM_NAME Domain on mcjannek ###"
realm discover $REALM_NAME

echo ""
echo "### 7. Join mcjannek to the $REALM_NAME Domain ###"
echo "## You will be prompted for the password for '$DOMAIN_USER_FOR_JOIN'. It is: $DOMAIN_USER_PASSWORD_HINT"
echo "## IMPORTANT: Take a SCREENSHOT of the successful join command output!"
realm join --user=$DOMAIN_USER_FOR_JOIN $REALM_NAME
# For AlmaLinux, explicit computer-ou might be needed if pre-staging is used, but not for basic join.
# Example: realm join --user=administrator --computer-ou="OU=LinuxServers,DC=repo,DC=internal" REPO.INTERNAL

echo ""
echo "### 8. Verify Domain Join on mcjannek ###"
echo "## IMPORTANT: Take a SCREENSHOT of this 'realm list' output!"
realm list
echo "## Check if the machine is listed and 'client-software' is 'sssd'."

echo ""
echo "--- Phase 2 for mcjannek complete. ---"

# --- Phase 3: Configure SSSD, NSS, PAM ---
echo ""
echo "--- Phase 3: Configure SSSD, NSS, PAM ---"

echo ""
echo "### 9. Configure SSSD (/etc/sssd/sssd.conf) on mcjannek ###"
echo "## Backing up /etc/sssd/sssd.conf to /etc/sssd/sssd.conf.bak"
cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.bak
echo "## Current SSSD config:"
cat /etc/sssd/sssd.conf
echo ""
echo "## Applying SSSD configurations for $DOMAIN_NAME..."
# Ensure [sssd] section has domains listed
if ! grep -q "^\s*domains\s*=" /etc/sssd/sssd.conf; then
    sed -i "/^\s*\[sssd\]/a domains = $DOMAIN_NAME" /etc/sssd/sssd.conf
elif ! grep -q "^\s*domains\s*=.*\b$DOMAIN_NAME\b" /etc/sssd/sssd.conf; then
    sed -i "s/^\(\s*domains\s*=\s*\)/\1$DOMAIN_NAME,/" /etc/sssd/sssd.conf # Add if not present
    sed -i "s/,\s*,/,/g" /etc/sssd/sssd.conf # Clean up double commas
fi

# Ensure [domain/repo.internal] section has necessary settings
# This uses crude sed, better to use Augeas or manual edit if complex existing config
CONFIG_BLOCK="[domain/$DOMAIN_NAME]\nid_provider = ad\nauth_provider = ad\naccess_provider = ad\nchpass_provider = ad\ndefault_shell = /bin/bash\nfallback_homedir = /home/%u@%d\nuse_fully_qualified_names = True\nkrb5_store_password_if_offline = True\nldap_id_mapping = True\n# Optional: ad_hostname = mcjannek.$DOMAIN_NAME (if FQDN issues)\n# Optional: ad_server = $DOMAIN_CONTROLLER_HOSTNAME"

if grep -q "^\s*\[domain/$DOMAIN_NAME\]" /etc/sssd/sssd.conf; then
    echo "## Domain section [domain/$DOMAIN_NAME] found. Will try to update specific keys."
    # Simple sed replacements for key values - add more as needed
    sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/s/^\(\s*use_fully_qualified_names\s*=\s*\).*/\1True/" /etc/sssd/sssd.conf
    sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/s/^\(\s*fallback_homedir\s*=\s*\).*/\1\/home\/%u@%d/" /etc/sssd/sssd.conf
    sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/s/^\(\s*default_shell\s*=\s*\).*/\1\/bin\/bash/" /etc/sssd/sssd.conf
    # Add if not present (simple append, might not be in the right place if section is minimal)
    if ! grep -q "^\s*use_fully_qualified_names\s*=" /etc/sssd/sssd.conf | sed -n "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/p"; then sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/a use_fully_qualified_names = True" /etc/sssd/sssd.conf; fi
    if ! grep -q "^\s*fallback_homedir\s*=" /etc/sssd/sssd.conf | sed -n "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/p"; then sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/a fallback_homedir = /home/%u@%d" /etc/sssd/sssd.conf; fi
    if ! grep -q "^\s*default_shell\s*=" /etc/sssd/sssd.conf | sed -n "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/p"; then sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/a default_shell = /bin/bash" /etc/sssd/sssd.conf; fi
    if ! grep -q "^\s*id_provider\s*=" /etc/sssd/sssd.conf | sed -n "/^\s*\[domain\/$DOMAIN_NAME\]/,/^\s*\[/p"; then sed -i "/^\s*\[domain\/$DOMAIN_NAME\]/a id_provider = ad" /etc/sssd/sssd.conf; fi
else
    echo "## Domain section [domain/$DOMAIN_NAME] not found. Appending."
    echo -e "\n$CONFIG_BLOCK" >> /etc/sssd/sssd.conf
fi
# Ensure proper permissions for sssd.conf
chmod 0600 /etc/sssd/sssd.conf
echo "## Updated /etc/sssd/sssd.conf (for review):"
cat /etc/sssd/sssd.conf

echo ""
echo "### 10. Configure Name Service Switch (NSS) and PAM using authselect on mcjannek ###"
# authselect handles nsswitch.conf and PAM configurations for sssd
authselect select sssd with-mkhomedir --force
echo "## NSS and PAM configured by authselect."
echo "## Current /etc/nsswitch.conf (for review):"
cat /etc/nsswitch.conf

echo ""
echo "### 11. Restart SSSD and Oddjob (for mkhomedir) and check status on mcjannek ###"
systemctl restart sssd oddjobd
systemctl status sssd
systemctl status oddjobd
echo "## If sssd or oddjobd fails to start, check 'journalctl -xeu sssd' or 'journalctl -xeu oddjobd'."

echo ""
echo "### 12. Test Domain User Resolution on mcjannek ###"
echo "## IMPORTANT: Take a SCREENSHOT of this 'id' command output!"
echo "## Attempt to get user info for $DOMAIN_USER_FOR_JOIN:"
id $DOMAIN_USER_FOR_JOIN
echo "## This should return UID/GID information for the domain user."

echo ""
echo "--- Phase 3 for mcjannek complete. ---"

# --- Phase 4: SSH Configuration and Login Test ---
echo ""
echo "--- Phase 4: SSH Configuration and Login Test ---"

echo ""
echo "### 13. Configure SSHD for Domain Logins on mcjannek ###"
echo "## Backing up /etc/ssh/sshd_config to /etc/ssh/sshd_config.bak"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "## Current SSHD config related to PasswordAuthentication/ChallengeResponseAuthentication:"
grep -E "^(PasswordAuthentication|ChallengeResponseAuthentication)" /etc/ssh/sshd_config || echo "## SSHD password/challenge options not explicitly set (using defaults)."
echo "## Ensuring 'PasswordAuthentication yes' and 'ChallengeResponseAuthentication yes' are set."
# Use sed to change 'no' to 'yes' or uncomment and set to 'yes'
sed -i 's/^\s*PasswordAuthentication\s*no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^\s*#\s*PasswordAuthentication\s*no/PasswordAuthentication yes/' /etc/ssh/sshd_config
if ! grep -q "^\s*PasswordAuthentication\s*yes" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi
sed -i 's/^\s*ChallengeResponseAuthentication\s*no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^\s*#\s*ChallengeResponseAuthentication\s*no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
if ! grep -q "^\s*ChallengeResponseAuthentication\s*yes" /etc/ssh/sshd_config; then
    echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
fi
echo "## Updated SSHD config lines (for review):"
grep -E "^(PasswordAuthentication|ChallengeResponseAuthentication)" /etc/ssh/sshd_config

echo ""
echo "### 14. Restart SSHD on mcjannek ###"
systemctl restart sshd
systemctl status sshd

echo ""
echo "### 15. Perform SSH Login Test for mcjannek ###"
echo "## From ANOTHER machine, attempt to SSH as $DOMAIN_USER_FOR_JOIN@172.21.0.102"
echo "## Command: ssh $DOMAIN_USER_FOR_JOIN@172.21.0.102"
echo "## You should be prompted for $DOMAIN_USER_FOR_JOIN's password ($DOMAIN_USER_PASSWORD_HINT)."
echo "## IMPORTANT: CAPTURE A SCREENSHOT of the successful SSH login for your report."
echo "## Type 'exit' to close the SSH session."

echo ""
echo ">>> mcjannek domain join and authentication setup script COMPLETE. <<<"
echo ">>> Review all output, check services, and perform the SSH test. <<<" 
