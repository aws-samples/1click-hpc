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

configureEF4ALB() {

    cat <<-EOF >> ${EF_CONF_ROOT}/plugins/interactive/interactive.efconf
INTERACTIVE_SESSION_STARTING_HOOK=${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh
INTERACTIVE_SESSION_CLOSING_HOOK=${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh
EOF

    cat <<-EOF >> ${EF_CONF_ROOT}/enginframe/agent.conf
ef.download.server.url=https://127.0.0.1:8443/enginframe/download
EOF

    alb_name="$(echo $stack_name | sed 's/hpc-1click-//')"
    ALB_PUBLIC_DNS_NAME=$(aws elbv2 describe-load-balancers --names "${alb_name}" --query "LoadBalancers[? LoadBalancerName == '${alb_name}'].DNSName" --output text --region "${cfn_region}")

    pattern='^ALB_PUBLIC_DNS_NAME=.*$'
    replace="ALB_PUBLIC_DNS_NAME=${ALB_PUBLIC_DNS_NAME}"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"

    pattern='^export AWS_DEFAULT_REGION=.*$'
    replace="export AWS_DEFAULT_REGION=${cfn_region}"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    sed -i -e "s|${pattern}|${replace}|" "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"

}


downloadALBhooks() {
    
    aws s3 cp --quiet "${post_install_base}/enginframe/alb.session.closing.hook.sh" "${EF_DATA_ROOT}/plugins/interactive/bin/" --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/enginframe/alb.session.starting.hook.sh" "${EF_DATA_ROOT}/plugins/interactive/bin/" --region "${cfn_region}" || exit 1

    ### FIX: DO NOT TO HARDCODE usernames
    chown ec2-user:efnobody "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"
    chmod +x "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.closing.hook.sh"
    chown ec2-user:efnobody "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
    chmod +x "${EF_DATA_ROOT}/plugins/interactive/bin/alb.session.starting.hook.sh"
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 12.configure.enginframe.alb.headnode.sh: START" >&2
    downloadALBhooks
    configureEF4ALB
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 12.configure.enginframe.alb.headnode.sh: STOP" >&2
    
}

main "$@"
