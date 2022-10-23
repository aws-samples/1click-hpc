#!/bin/bash
set -x
set -e

activateSSSD() {
    #sed -i '0,/use_fully_qualified_names = False$/s//use_fully_qualified_names = False\nldap_user_extra_attrs = altSecurityIdentities\nldap_user_ssh_public_key = altSecurityIdentities/' /etc/sssd/sssd.conf
    #sed -i '/^ldap_search_base/ s/$/?subtree?(&(!(objectClass=computer))(!(userAccountControl:1.2.840.113556.1.4.803:=2)))/' /etc/sssd/sssd.conf
    #sed -i '0,/^[domain/default]/a enumerate = true' /etc/sssd/sssd.conf
    sed -i 's/fallback_homedir = \/home\/%u/override_homedir = \/fsx\/home-%u/g' /etc/sssd/sssd.conf
        ROU_PW=$(aws secretsmanager get-secret-value --secret-id "${stack_name}-ROU" --query SecretString --output text --region "${cfn_region}")
    sed -E -i "s|^#?(ldap_default_authtok\s=)\s.*|\1 ${ROU_PW}|" /etc/sssd/sssd.conf
    #systemctl stop sssd
    #rm -rf /var/lib/sss/{db,mc}/*
    systemctl restart sssd
}

addAdmins2Sudoers() {
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
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.sudo.compute.sh: START" >&2
    activateSSSD
    addAdmins2Sudoers
    #setupCron
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.activate.passwordless.sudo.compute.sh: STOP" >&2
}

main "$@"



