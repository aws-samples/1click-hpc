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


# Intall DCV con compute Nodes.
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"
export DCV_KEY_WORD=$(jq --arg default "dcv" -r '.post_install.dcv | if has("dcv_queue_keyword") then .dcv_queue_keyword else $default end' "${dna_json}")
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
export EF_NAT_CONF="${NICE_ROOT}/enginframe/conf/plugins/interactive/nat.conf"


set -x
set -e

fixNat() {
    
    #fix the nat
    h1=$(hostname)
    h2="${h1//./\\.}"
    sed -i "/^${h2} .*$/d" "${EF_NAT_CONF}"
    echo "$h1 $(ec2-metadata -p| awk '{print $2}')" >> "${EF_NAT_CONF}"
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 27.configure.dcv.nat.compute.sh: START" >&2

    for conf_file in $(ls ${SLURM_CONF_FILE} | grep "${DCV_KEY_WORD}"); do
        if [[ ! -z $(grep "${compute_instance_type}" "${conf_file}") ]]; then
            fixNat
        fi
    done
        
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 27.configure.dcv.nat.compute.sh: STOP" >&2
}

main "$@"