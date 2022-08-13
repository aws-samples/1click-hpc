#!/bin/bash
set -x
set -e

activateSSH() {
    sed -i '0,/use_fully_qualified_names = False$/s//use_fully_qualified_names = False\nldap_user_extra_attrs = altSecurityIdentities\nldap_user_ssh_public_key = altSecurityIdentities/' /etc/sssd/sssd.conf
    #sed -i '/^ldap_search_base/ s/$/?subtree?(&(!(objectClass=computer))(!(userAccountControl:1.2.840.113556.1.4.803:=2)))/' /etc/sssd/sssd.conf
    sed -i '0,/^[domain/default]/a enumerate = true' /etc/sssd/sssd.conf
    systemctl stop sssd
    rm -rf /var/lib/sss/{db,mc}/*
    systemctl start sssd
    echo "AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys" >> /etc/ssh/sshd_config
    echo "AuthorizedKeysCommandUser root" >> /etc/ssh/sshd_config
    systemctl restart sshd
}

addAdmins2Sudoers() {
    echo "${ec2user_pass}" | passwd ec2-user --stdin
    cat > /etc/sudoers.d/100-AD-admins << EOF
# add domain admins as sudoers
%Sudoers  ALL=(ALL) NOPASSWD:ALL
EOF
}

removePasswordAuth(){
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config
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
    #removePasswordAuth
    setupCron
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.AD.headnode.sh: STOP" >&2
}

main "$@"