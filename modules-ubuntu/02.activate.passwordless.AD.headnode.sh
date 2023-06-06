#!/bin/bash
set -x
set -e
source "/etc/parallelcluster/cfnconfig"

activateSSH() {
    sed -i 's/fallback_homedir = \/home\/%u/override_homedir = \/fsx\/home-%u/g' /etc/sssd/sssd.conf
    ROU_PW=$(aws secretsmanager get-secret-value --secret-id "${stack_name}-ROU" --query SecretString --output text --region "${cfn_region}")
    sed -E -i "s|^#?(ldap_default_authtok\s=)\s.*|\1 ${ROU_PW}|" /etc/sssd/sssd.conf

    systemctl restart sssd
    echo "AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys" >> /etc/ssh/sshd_config
    echo "AuthorizedKeysCommandUser root" >> /etc/ssh/sshd_config
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config
    apt-get remove ec2-instance-connect #required on ubuntu2004 https://github.com/widdix/aws-ec2-ssh/issues/157
    systemctl restart sshd
}

addAdmins2Sudoers() {
    #echo "${ec2user_pass}" | passwd ubuntu
    cat > /etc/sudoers.d/100-AD-admins << EOF
# add domain admins as sudoers
%Sudoers  ALL=(ALL) NOPASSWD:ALL
EOF
}

setupCron(){
    # Configure the script to run every minute
    echo "
*/10 * * * * systemctl stop sssd; rm -rf /var/lib/sss/{db,mc}/*; systemctl start sssd
" | crontab -
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.AD.headnode.sh: START" >&2
    activateSSH
    addAdmins2Sudoers
    #setupCron
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.AD.headnode.sh: STOP" >&2
}

main "$@"