## Inject: Join swiftbroom to REPO.INTERNAL Domain
## Phase 1: Prerequisites (DNS, Time, Packages) for swiftbroom

echo "### 1. Configure DNS for swiftbroom ###"
echo "## Backing up /etc/resolv.conf to /etc/resolv.conf.bak"
sudo cp /etc/resolv.conf /etc/resolv.conf.bak
echo "## Setting DNS to headman (172.21.0.103) and a public fallback (1.1.1.1)"
echo "nameserver 172.21.0.103" | sudo tee /etc/resolv.conf > /dev/null
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
echo "## Displaying new /etc/resolv.conf"
cat /etc/resolv.conf
echo "## NOTE: If NetworkManager is active, it might overwrite /etc/resolv.conf."
echo "## You may need to configure DNS in NetworkManager settings or disable its resolv.conf management."
echo "## For now, we proceed with the manual change. Test DNS resolution for the DC:"
ping -c 3 headman.repo.internal
ping -c 3 repo.internal

echo ""
echo "### 2. Install and Configure Time Synchronization (chrony) for swiftbroom ###"
sudo apt update
sudo apt install chrony -y
echo "## Backing up /etc/chrony/chrony.conf to /etc/chrony/chrony.conf.bak"
sudo cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
echo "## Configuring chrony to use headman (172.21.0.103) as NTP source"
echo "server 172.21.0.103 iburst" | sudo tee /etc/chrony/chrony.conf > /dev/null
echo "pool 2.debian.pool.ntp.org iburst" | sudo tee -a /etc/chrony/chrony.conf > /dev/null # Fallback
sudo systemctl restart chrony
echo "## Waiting a few seconds for chrony to sync..."
sleep 10
echo "## Checking chrony sources and sync status"
chronyc sources
chronyc tracking

echo ""
echo "### 3. Install Required Packages for AD Integration on swiftbroom ###"
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin krb5-user packagekit -y
echo "## During krb5-user installation, if prompted for Kerberos default realm, enter: REPO.INTERNAL"

echo ""
echo "### Phase 1 for swiftbroom complete. Review output carefully. ###"
echo "### Ensure DNS resolves headman.repo.internal and time is synchronizing. ###"
