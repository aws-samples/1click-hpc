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


installSimpleExternalAuth() {
    
    yum -y install nice-dcv-*/nice-dcv-simple-external-authenticator-*.rpm
    
    systemctl start dcvsimpleextauth.service

}

installDCVGLonG4() {
    systemctl isolate multi-user.target
    
    nvidia-xconfig --enable-all-gpus --preserve-busid  --connected-monitor=DFP-0,DFP-1,DFP-2,DFP-3
    nvidia-persistenced
    nvidia-smi -ac 5001,1590
                         
    yum -y install nice-dcv-*/nice-dcv-gltest*.rpm nice-dcv-*/nice-dcv-gl-*.x86_64.rpm
    
    systemctl isolate graphical.target
}

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
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-server.compute.sh: START" >&2

    for conf_file in $(ls ${SLURM_CONF_FILE} | grep "${DCV_KEY_WORD}"); do
        if [[ ! -z $(grep "${compute_instance_type}" "${conf_file}") ]]; then
            wget -nv https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el7-x86_64.tgz
            tar zxvf nice-dcv-el7-x86_64.tgz
            if [[ $compute_instance_type == *"g4"* ]]; then
                installDCVGLonG4
            fi
            installSimpleExternalAuth
            dcvusbdriverinstaller --quiet
            fixNat
        fi
    done
        
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.dcv-server.compute.sh: STOP" >&2
}

main "$@"