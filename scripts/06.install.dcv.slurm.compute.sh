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

export DCV_KEY_WORD=$(jq --arg default "dcv" -r '.post_install.dcv | if has("dcv_queue_keyword") then .dcv_queue_keyword else $default end' "${dna_json}")
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"

set -x
set -e

installMissingLib() {
    yum -y install ImageMagick
}

configureDCVexternalAuth() {
    
    pattern='\[security\]'
    replace='&\n'
    replace+="auth-token-verifier=\"http://localhost:8444\""
    cp '/etc/dcv/dcv.conf' "/etc/dcv/dcv.conf.$(date --iso=s --utc)"
    # remove duplicates if any
    #sed -i -e '/^ *\(administrators\|ca-file\|auth-token-verifier\) *=.*$/d' '/etc/dcv/dcv.conf'
    sed -i -e "s|${pattern}|${replace}|" '/etc/dcv/dcv.conf'

}

restartDCV() {
    
    systemctl restart dcvserver.service

}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv.slurm.compute.sh: START" >&2
    
    for conf_file in $(ls ${SLURM_CONF_FILE} | grep "${DCV_KEY_WORD}"); do
        if [[ ! -z $(grep "${compute_instance_type}" "${conf_file}") ]]; then
            installMissingLib
            configureDCVexternalAuth
            restartDCV
        fi
    done
    
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv.slurm.compute.sh: STOP" >&2
}

main "$@"