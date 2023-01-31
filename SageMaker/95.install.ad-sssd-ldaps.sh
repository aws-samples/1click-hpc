#!/bin/bash
set -x
set -e
set -o pipefail

echo "Setup sssd connection to Active Directory via LDAP on `hostname`"

sshd_config_file="/etc/ssh/sshd_config"
ec2_connect_conf="/usr/lib/systemd/system/ssh.service.d/ec2-instance-connect.conf"
sssd_conf_file="/admin/config/sssd.conf"

echo ""
echo "###################################################"
echo "Step 2: Running apt-get update"
echo "###################################################"
sudo apt-get update -y
echo "apt-get update finished..."

echo ""
echo "###################################################"
echo "Step 3: Running apt-get upgrade"
echo "###################################################"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq sssd sssd-tools sssd-ldap
echo "required package installation complete..."


if [ -d "/etc/sssd" ]
then
        echo "Found sssd directory. Proceeding..."
else
        echo "sssd configuration directory not found."
        sudo mkdir -p /etc/sssd
fi

sudo cp $sssd_conf_file /etc/sssd/sssd.conf
sudo chmod 0600 /etc/sssd/sssd.conf

sudo systemctl restart sssd

echo ""
echo "###################################################"
echo "Step 4: ssh Auth setup"
echo "###################################################"
## Allow password authentication for SSH
sudo sed -i 's/[#]AuthorizedKeysCommand .*/AuthorizedKeysCommand \/usr\/bin\/sss_ssh_authorizedkeys/' $sshd_config_file
sudo sed -i 's/[#]AuthorizedKeysCommandUser .*/AuthorizedKeysCommandUser root/' $sshd_config_file
sudo sed -i 's/[#]PasswordAuthentication .*/PasswordAuthentication no/' $sshd_config_file

sudo sed -i -e 's/^/#/' $ec2_connect_conf
sudo systemctl daemon-reload

cat > /etc/sudoers.d/100-AD-admins << EOF
# add domain admins as sudoers
%Sudoers  ALL=(ALL) NOPASSWD:ALL
EOF


# restart ssh service
echo "Restarting sshd..."
sudo systemctl restart sshd
echo "Done"

echo "AD Setup Completed."