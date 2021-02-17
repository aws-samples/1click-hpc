#!/bin/bash

install_client_packages() {
    yum install -y openldap-clients nss-pam-ldapd
}

prepare_ldap_client() {
    source /etc/parallelcluster/cfnconfig
    source /home/.ldap
    authconfig --enableldap \
               --enableldapauth \
               --ldapserver=${ldap_server} \
               --ldapbasedn="dc=${stack_name},dc=internal" \
               --enablemkhomedir \
               --update
    systemctl restart nslcd
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.client.master.sh: START" >&2

    source /etc/parallelcluster/cfnconfig
    install_client_packages
    prepare_ldap_client

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.client.master.sh: STOP" >&2
}

main "$@"
