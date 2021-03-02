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
if [[ $# -eq 2 ]] && [[ -n "$1" ]]; then
  USERNAME=$1
  PASS=$2
else
  echo "Usage: `basename $0` <user-name>"
  echo "<user-name> must be a string"
  exit 1
fi

# Load env vars which identify instance type
.  /etc/parallelcluster/cfnconfig

args=(-x -W -D "cn=ldapadmin,dc=${stack_name},dc=internal" -y /root/.ldappasswd)

storedId=$(ldapsearch "${args[@]}" "(&(objectClass=uidNext)(cn=uidNext))" "uidNumber" | awk '$1=="uidNumber:" {print $2}')
nextId="${storedId}"
while :; do
  name=$(ldapsearch "${args[@]}" "(&(objectClass=posixAccount)(uidNumber=${nextId}))" name | awk '$1=="name:" {print $2}')
  [[ -z $name ]] && break
  ((nextId++))
done

ldapmodify "${args[@]}" <<EOF >/dev/null
dn: cn=uidNext,dc=${stack_name},dc=internal
changetype: modify
delete: uidNumber
uidNumber: ${storedId}
-
add: uidNumber
uidNumber: $((nextId+1))
EOF

ldapadd "${args[@]}" <<EOF >/dev/null 2>test
dn: uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: ${USERNAME}
uid: ${USERNAME}
uidNumber: ${nextId}
gidNumber: 100
homeDirectory: /home/${USERNAME}
loginShell: /bin/bash
EOF

if grep -q "Already exists" "test"; then
    rm -f test
    echo "User already exists."
    exit -1
fi

# Set a temporary password for the user
ldappasswd -H ldap://localhost:389 "${args[@]}" -s ${PASS} uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal 

sudo -H -u ${USERNAME} bash -c "ssh-keygen -q -t rsa -b 4096 -N \"\" -f ~/.ssh/id_rsa; cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"