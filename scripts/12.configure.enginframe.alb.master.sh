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

source '/etc/parallelcluster/cfnconfig'
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
export EF_CONF_ROOT=$(jq --arg default "${NICE_ROOT}/enginframe/conf" -r '.post_install.enginframe | if has("ef_conf_root") then .ef_conf_root else $default end' "${dna_json}")
export EF_DATA_ROOT=$(jq --arg default "${NICE_ROOT}/enginframe/data" -r '.post_install.enginframe | if has("ef_data_root") then .ef_data_root else $default end' "${dna_json}")

set -x
set -e

configureEF4ALB() {

    cat <<-EOF >> ${EF_CONF_ROOT}/plugins/interactive/interactive.efconf
INTERACTIVE_SESSION_STARTING_HOOK=${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh
INTERACTIVE_SESSION_CLOSING_HOOK=${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh
EOF
    
    pattern='^ALB_PUBLIC_DNS_NAME=.*$'
    replace="ALB_PUBLIC_DNS_NAME=${ALB_PUBLIC_DNS_NAME}"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"

    pattern='^export AWS_DEFAULT_REGION=.*$'
    replace="export AWS_DEFAULT_REGION=${cfn_region}"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"

}


downlaodALBhooks() {
                            
    wget -P "${EF_DATA_ROOT}/plugins/interactive/bin/" "${post_install_base}/enginframe/alb.session.closing.hook.sh" || exit 1
    ### FIX: DO NOT TO HARDCODE usernames
    chown ec2-user:efnobody "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"
    chmod +x "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"
    
    wget -P "${EF_DATA_ROOT}/plugins/interactive/bin/" "${post_install_base}/enginframe/alb.session.starting.hook.sh" || exit 1
    ### FIX: DO NOT TO HARDCODE usernames
    chown ec2-user:efnobody "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    chmod +x "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 12.configure.enginframe.alb.master.sh: START" >&2
    downlaodALBhooks
    configureEF4ALB
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 12.configure.enginframe.alb.master.sh: STOP" >&2
    
}

main "$@"
