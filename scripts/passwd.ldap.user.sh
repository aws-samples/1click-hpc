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

ldap_home="/home/efnobody"
ldap_pass="${ldap_home}/.ldappasswd"

# Only take action if two arguments are provided
if [[ $# -eq 3 ]] && [[ -n "$1" ]]; then
  USERNAME="${1}"
  PASS="${2}"
  OLD_PASS="${3}"
else
  echo "Usage: `basename $0` <user-name> <new_password> <old_password>"
  echo "<user-name> must be a string"
  exit 1
fi

if [[ ${#PASS} -lt 8 ]]; then
  echo "The new password must have at least 8 characters"
  exit 1
elif [[ ! ${PASS} =~ [[:upper:]]+ ]]; then
  echo "The new password must contain at least one uppercase character"
  exit 1
elif [[ ! ${PASS} =~ [[:lower:]]+ ]]; then
  echo "The new password must contain at least one lowercase character"
  exit 1
elif [[ ! ${PASS} =~ [[:digit:]]+ ]]; then
  echo "The new password must contain at least one digit"
  exit 1
else

  # Load env vars which identify instance type
  .  /etc/parallelcluster/cfnconfig

  args=(
    -x -H ldap://localhost:389
    -D "uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal"
    -w "${OLD_PASS}"
    -s "${PASS}"
  )
  
  ldappasswd "${args[@]}"
fi