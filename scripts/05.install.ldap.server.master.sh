#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

install_server_packages() {
    yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel
}

prepare_ldap_server() {
    # Start the server
    systemctl start slapd
    systemctl enable slapd
    # Generate a random string to use as the password
    echo $RANDOM | md5sum | awk '{ print $1 }' > /root/.ldappasswd
    chmod 400 /root/.ldappasswd
    # Use the password to generate a ldap password hash
    LDAP_HASH=$(slappasswd -T /root/.ldappasswd)
    # Initial LDAP setup specification
    cat <<-EOF > /root/ldapdb.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=${stack_name},dc=internal

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=ldapadmin,dc=${stack_name},dc=internal

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: ${LDAP_HASH}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword
  by self write
  by * auth
olcAccess: {1}to *
  by * read
EOF
    # Apply LDAP settings
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/ldapdb.ldif
    # Apply LDAP database settings
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap:ldap /var/lib/ldap/*
    # Apply minimal set of LDAP schemas
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    # Specify a minimal directory structure
    cat <<-EOF > /root/struct.ldif
dn: dc=${stack_name},dc=internal
dc: ${stack_name}
objectClass: top
objectClass: domain

dn: cn=ldapadmin ,dc=${stack_name},dc=internal
objectClass: organizationalRole
cn: ldapadmin
description: LDAP Admin

dn: ou=Users,dc=${stack_name},dc=internal
objectClass: organizationalUnit
ou: Users
EOF
    # Apply the directory structure
    ldapadd -x -W -D "cn=ldapadmin,dc=${stack_name},dc=internal" -f /root/struct.ldif -y /root/.ldappasswd
    # Save the controller hostname to a shared location for later use
    echo "ldap_server=$(hostname)" > /home/.ldap
}

restart_scheduler() {
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.server.master.sh: START" >&2
    
    source /etc/parallelcluster/cfnconfig
    install_server_packages
    prepare_ldap_server
    restart_scheduler

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.server.master.sh: STOP" >&2
}

main "$@"
