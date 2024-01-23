#!/bin/bash
set -x
set -e
source "/etc/parallelcluster/cfnconfig"

activateSSSD() {
    sed -i 's/fallback_homedir = \/home\/%u/override_homedir = \/admin\/home-%u/g' /etc/sssd/sssd.conf
    searchstring="-ComputeFleet"
    stack=${stack_name%$searchstring*}
    ROU_PW=$(aws secretsmanager get-secret-value --secret-id "newADrouPassword" --query SecretString --output text --region "${cfn_region}" --cli-connect-timeout 1)
    sed -E -i "s|^#?(ldap_default_authtok\s=)\s.*|\1 ${ROU_PW}|" /etc/sssd/sssd.conf
    
    #patch for ingresseast to avoid redeploying
    sed -E -i "s|^#?(ldap_uri\s=)\s.*us-east-1.*|ldap_uri = ldaps://ldaps-d171c2d625ffa6d5.elb.us-east-1.amazonaws.com|" /etc/sssd/sssd.conf
    sed -E -i "s|^#?(ldap_default_bind_dn\s=)\s.*|\1 cn=ReadOnlyUser,ou=AD-Manage,dc=research,dc=stability,dc=ai|" /etc/sssd/sssd.conf
    
    apt-get remove -y ec2-instance-connect #required on ubuntu2004 https://github.com/widdix/aws-ec2-ssh/issues/157
    systemctl restart sssd
}

addAdmins2Sudoers() {
    #echo "${ec2user_pass}" | passwd ec2-user --stdin
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



