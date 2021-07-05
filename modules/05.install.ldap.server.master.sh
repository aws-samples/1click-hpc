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

set -x
set -e

source /etc/parallelcluster/cfnconfig

ldap_home="/home/efnobody"
ldap_pass="${ldap_home}/.ldappasswd"

args=(-x -W -D "cn=ldapadmin,dc=${stack_name},dc=internal" -y "${ldap_pass}")

install_server_packages() {
    yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel
}

prepare_ldap_server() {
    
    # add EnginFrame users if not already exist
    id -u efnobody &>/dev/null || adduser efnobody
    
    # Start the server
    systemctl start slapd
    systemctl enable slapd
    # Generate a random string to use as the password
    echo $RANDOM | md5sum | awk '{ print $1 }' > "${ldap_pass}"
    chmod 400 "${ldap_pass}"
    chown efnobody:efnobody "${ldap_pass}"
    
    # Use the password to generate a ldap password hash
    LDAP_HASH=$(slappasswd -T "${ldap_pass}")
    
    # Initial LDAP setup specification
    cat <<-EOF > ${ldap_home}/ldapdb.ldif
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="cn=ldapadmin,dc=${stack_name},dc=internal" read by * none

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
    ldapmodify -Y EXTERNAL -H ldapi:/// -f "${ldap_home}/ldapdb.ldif"
    chown efnobody:efnobody "${ldap_home}/ldapdb.ldif"
    
    ldapadd -Y EXTERNAL -H ldapi:/// <<'EOF'
dn: cn=idnext,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: idnext
olcObjectClasses: {0}( 1.3.6.1.4.1.7165.1.2.2.3
  NAME 'uidNext' SUP top STRUCTURAL
  DESC 'Next available UNIX uid'
  MUST ( uidNumber $ cn ) )
olcObjectClasses: {1}( 1.3.6.1.4.1.7165.1.2.2.4
  NAME 'gidNext' SUP top STRUCTURAL
  DESC 'Next available UNIX gid'
  MUST ( gidNumber $ cn ) )
EOF

    # Apply LDAP database settings
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap:ldap /var/lib/ldap/*
    # Apply minimal set of LDAP schemas
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    # Specify a minimal directory structure
    cat <<-EOF > ${ldap_home}/struct.ldif
dn: dc=${stack_name},dc=internal
dc: ${stack_name}
objectClass: top
objectClass: domain

dn: cn=ldapadmin,dc=${stack_name},dc=internal
objectClass: organizationalRole
cn: ldapadmin
description: LDAP Admin

dn: ou=Users,dc=${stack_name},dc=internal
objectClass: organizationalUnit
ou: Users

dn: cn=uidNext,dc=${stack_name},dc=internal
objectClass: uidNext
cn: uidNext
uidNumber: 2001

dn: cn=gidNext,dc=${stack_name},dc=internal
objectClass: gidNext
cn: gidNext
gidNumber: 2001
EOF
    # Apply the directory structure
    ldapadd "${args[@]}" -f "${ldap_home}/struct.ldif"
    chown efnobody:efnobody "${ldap_home}/struct.ldif"
    
    # Save the controller hostname to a shared location for later use
    echo "ldap_server=$(hostname)" > /home/.ldap
}


downlaod_ldap_tools() {
    
    if [[ ${proto} == "https://" ]]; then
        wget -nv -P /usr/sbin/ "${post_install_url}/add.ldap.user.sh"    || exit 1
        wget -nv -P /usr/sbin/ "${post_install_url}/remove.ldap.user.sh" || exit 1
        wget -nv -P /usr/sbin/ "${post_install_url}/passwd.ldap.user.sh" || exit 1
        wget -nv -P /etc/profile.d/ "${post_install_url}/autosshkeys.sh" || exit 1
    elif [[ ${proto} == "s3://" ]]; then
        aws s3 cp "${post_install_url}/add.ldap.user.sh" /usr/sbin/ --region "${cfn_region}" || exit 1
        aws s3 cp "${post_install_url}/remove.ldap.user.sh" /usr/sbin/ --region "${cfn_region}" || exit 1
        aws s3 cp "${post_install_url}/passwd.ldap.user.sh" /usr/sbin/ --region "${cfn_region}" || exit 1
        aws s3 cp "${post_install_url}/autosshkeys.sh" /etc/profile.d/ --region "${cfn_region}" || exit 1
    else
        exit 1
    fi
    
    chmod 755 /usr/sbin/add.ldap.user.sh
    chmod 755 /usr/sbin/remove.ldap.user.sh
    chmod 755 /usr/sbin/passwd.ldap.user.sh
    chmod 755 /etc/profile.d/autosshkeys.sh
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.server.master.sh: START" >&2
    
    install_server_packages
    prepare_ldap_server
    downlaod_ldap_tools
    
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.server.master.sh: STOP" >&2
}

main "$@"