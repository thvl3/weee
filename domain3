## Phase 3: Configure SSSD, PAM, NSS, and SSHD for swiftbroom

echo ""
echo "### 8. Configure SSSD (/etc/sssd/sssd.conf) on swiftbroom ###"
echo "## Backing up /etc/sssd/sssd.conf to /etc/sssd/sssd.conf.bak"
sudo cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.bak
echo "## Displaying current SSSD config:"
sudo cat /etc/sssd/sssd.conf

echo ""
echo "## IMPORTANT: You will now MANUALLY EDIT /etc/sssd/sssd.conf with 'sudo nano /etc/sssd/sssd.conf'"
echo "## Make sure the [sssd] section has 'domains = repo.internal' (or your discovered domain if different)"
echo "## Make sure a [domain/repo.internal] section exists and contains AT LEAST the following:"
echo "#   id_provider = ad"
echo "#   auth_provider = ad"
echo "#   access_provider = ad  # Or 'permit' if you want to allow all domain users by default and restrict later"
echo "#   default_shell = /bin/bash"
echo "#   fallback_homedir = /home/%u@%d"
echo "#   use_fully_qualified_names = True # Crucial for user@domain format!"
echo "#   krb5_store_password_if_offline = True"
echo "#   # You might also need/want 'ldap_id_mapping = True' if not already implicitly handled"
echo "#   # Ensure 'ad_domain = repo.internal' is present if not implicitly handled by discovery."
echo "## Remove or comment out 'ldap_sasl_authid' and 'ldap_sasl_منmechanism' if they exist and cause issues."
echo "## After editing, save the file."

# Note: We will restart sssd after nsswitch and PAM checks.

echo ""
echo "### 9. Configure Name Service Switch (/etc/nsswitch.conf) on swiftbroom ###"
echo "## Backing up /etc/nsswitch.conf to /etc/nsswitch.conf.bak"
sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
echo "## Displaying current nsswitch.conf:"
sudo cat /etc/nsswitch.conf
echo "## Ensure 'sss' is added to passwd, group, and shadow lines, BEFORE 'systemd'. E.g.:"
echo "# passwd: files sss systemd"
echo "# group:  files sss systemd"
echo "# shadow: files sss"
echo "## Use 'sudo nano /etc/nsswitch.conf' to edit."


echo ""
echo "### 10. Configure PAM (Pluggable Authentication Modules) on swiftbroom ###"
echo "## realmd should have configured basic PAM. We'll ensure critical settings."
echo "## Check pam_sss.so is present in common-auth and common-account:"
sudo grep pam_sss.so /etc/pam.d/common-auth /etc/pam.d/common-account
echo "## Check for pam_mkhomedir.so in common-session to create home directories:"
sudo grep pam_mkhomedir /etc/pam.d/common-session
echo "## If pam_mkhomedir.so is missing or commented out in common-session, add/uncomment it:"
echo "# session optional        pam_mkhomedir.so skel=/etc/skel/ umask=0077"
echo "## Use 'sudo nano /etc/pam.d/common-session' to edit if needed."

echo ""
echo "### 11. Restart SSSD and check its status on swiftbroom ###"
sudo systemctl restart sssd
sudo systemctl status sssd
echo "## If sssd fails to start, check 'journalctl -xeu sssd' for detailed errors."


echo ""
echo "### 12. Test Domain User Resolution on swiftbroom ###"
echo "## Attempt to get user info for taxman@REPO.INTERNAL:"
id taxman@REPO.INTERNAL
echo "## This should return UID/GID information for the domain user."

echo ""
echo "### Phase 3 for swiftbroom complete. ###"
echo "### If 'id taxman@REPO.INTERNAL' works, we are ready for SSH testing. ###"
