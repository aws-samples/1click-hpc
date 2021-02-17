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

# Only take action if two arguments are provided
if [ $# -eq 2 ] && [ "$2" -eq "$2" ] 2>/dev/null && [ "$2" -gt 1000 ]; then
  USERNAME=$1
  USERID=$2
else
  echo "Usage: `basename $0` <user-name> <user-id>"
  echo "<user-name> must be a string"
  echo "<user-id> must be an integer greater than 1000"
  exit 1
fi

# Load env vars which identify instance type
.  /etc/parallelcluster/cfnconfig

# Write a minimal LDAP object configuration for a user
cat <<-EOF > /tmp/${USERNAME}.ldif
dn: uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: ${USERNAME}
uid: ${USERNAME}
uidNumber: ${USERID}
gidNumber: 100
homeDirectory: /home/${USERNAME}
loginShell: /bin/bash
EOF

# Add the user to LDAP
ldapadd -x -W -D "cn=ldapadmin,dc=${stack_name},dc=internal" -f /tmp/${USERNAME}.ldif -y /root/.ldappasswd

# Tidy up and verify the entry was successful
rm /tmp/${USERNAME}.ldif
getent passwd $1

# Set a temporary password for the user
TMPPASS=$(echo $RANDOM | md5sum | awk '{ print $1 }')
ldappasswd -H ldap://localhost:389 -x -D "cn=ldapadmin,dc=${stack_name},dc=internal" -W -s ${TMPPASS} uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal -y /root/.ldappasswd
echo "Temporary password for ${USERNAME}: ${TMPPASS}"
