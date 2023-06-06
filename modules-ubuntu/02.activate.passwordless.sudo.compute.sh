#!/bin/bash
set -x
set -e
source "/etc/parallelcluster/cfnconfig"

activateSSSD() {
    sed -i 's/fallback_homedir = \/home\/%u/override_homedir = \/fsx\/home-%u/g' /etc/sssd/sssd.conf
    searchstring="-ComputeFleet"
    stack=${stack_name%$searchstring*}
    ROU_PW=$(aws secretsmanager get-secret-value --secret-id "${stack}-ROU" --query SecretString --output text --region "${cfn_region}")
    sed -E -i "s|^#?(ldap_default_authtok\s=)\s.*|\1 ${ROU_PW}|" /etc/sssd/sssd.conf
    apt-get remove ec2-instance-connect #required on ubuntu2004 https://github.com/widdix/aws-ec2-ssh/issues/157
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



