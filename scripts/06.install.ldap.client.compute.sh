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

install_client_packages() {
    yum install -y openldap-clients nss-pam-ldapd
}

prepare_ldap_client() {
    source /home/.ldap
    authconfig --enableldap \
               --enableldapauth \
               --ldapserver=${ldap_server} \
               --ldapbasedn="dc=${stack_name},dc=internal" \
               --enablemkhomedir \
               --update
    systemctl restart nslcd
    systemctl restart dbus
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.client.compute.sh: START" >&2

    source /etc/parallelcluster/cfnconfig
    install_client_packages
    prepare_ldap_client

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.client.compute.sh: STOP" >&2
}

main "$@"
