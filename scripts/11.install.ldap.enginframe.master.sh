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

# Modify EnginFrame user management to create and delete LDAP users.

source '/etc/parallelcluster/cfnconfig'
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
export EF_TOP="${NICE_ROOT}/enginframe"
unset EF_VERSION
source "${EF_TOP}/current-version"
export EF_ROOT="${EF_TOP}/${EF_VERSION}/enginframe"


# Downlaod from gitHub the modified EnginFrame services
# ----------------------------------------------------------------------------
configureEnginFrame() {

    mv "${EF_ROOT}/plugins/applications/WEBAPP/applications.admin.xml" "${EF_ROOT}/plugins/applications/WEBAPP/applications.admin.xml.$(date '+%Y-%m-%d-%H-%M-%S').BAK"
    wget -P "${EF_ROOT}/plugins/applications/WEBAPP/" "${post_install_base}/enginframe/applications.admin.xml" || exit 1
    
    mv "${EF_ROOT}/plugins/applications/bin/applications.manage.users.ui" "${EF_ROOT}/plugins/applications/bin/applications.manage.users.ui.$(date '+%Y-%m-%d-%H-%M-%S').BAK"
    wget -P "${EF_ROOT}/plugins/applications/bin/" "${post_install_base}/enginframe/applications.manage.users.ui" || exit 1
    
    wget -P "${EF_ROOT}/plugins/user-group-manager/lib/xml/" "${post_install_base}/enginframe/com.enginframe.ldap-user-group-manager.xml" || exit 1
    
    mv "${EF_ROOT}/plugins/user-group-manager/lib/xml/com.enginframe.user-group-manager.xml" "${EF_ROOT}/plugins/user-group-manager/lib/xml/com.enginframe.user-group-manager.xml.$(date '+%Y-%m-%d-%H-%M-%S').BAK"
    wget -P "${EF_ROOT}/plugins/user-group-manager/lib/xml/" "${post_install_base}/enginframe/com.enginframe.user-group-manager.xml" || exit 1
    
    mv "${EF_ROOT}/plugins/applications/WEBAPP/js/widgets/hydrogen.manage-users.js" "${EF_ROOT}/plugins/applications/WEBAPP/js/widgets/hydrogen.manage-users.js.$(date '+%Y-%m-%d-%H-%M-%S').BAK"
    wget -P "${EF_ROOT}/plugins/applications/WEBAPP/js/widgets/" "${post_install_base}/enginframe/hydrogen.manage-users.js" || exit 1
    
    mv "${EF_ROOT}/plugins/vdi/WEBAPP/vdi.admin.xml" "${EF_ROOT}/plugins/vdi/WEBAPP/vdi.admin.xml.$(date '+%Y-%m-%d-%H-%M-%S').BAK"
    wget -P "${EF_ROOT}/plugins/vdi/WEBAPP/" "${post_install_base}/enginframe/vdi.admin.xml" || exit 1

    sed -i \
        "s/^HY_CONNECT_SESSION_MAX_WAIT=.*$/HY_CONNECT_SESSION_MAX_WAIT='600'/" \
        "${EF_ROOT}/plugins/hydrogen/conf/ui.hydrogen.conf"             

}

startEnginFrame() {
  systemctl start enginframe
}

stopEnginFrame() {
  systemctl stop enginframe
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.enginframe.master.sh: START" >&2

    stopEnginFrame
    configureEnginFrame
    startEnginFrame

    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.ldap.enginframe.master.sh: STOP" >&2
}

main "$@"
