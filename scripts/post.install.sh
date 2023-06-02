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


# Top level post install script
set -a
source '/etc/parallelcluster/cfnconfig'
set +a

# run scripts
# ----------------------------------------------------------------------------
# runs secondary scripts according to the node type
runScripts() {
    
    echo "Getting packages from github"
    mkdir -p "${TMP_MODULES_DIR}"
    rm -rf /tmp/hpc
    git clone https://github.com/Stability-AI/stability-hpc /tmp/hpc
    for script in ${myscripts}; do
        cp /tmp/hpc/modules-ubuntu/${script} "${TMP_MODULES_DIR}" || exit 1
    done

    chmod 755 -R "${TMP_MODULES_DIR}"
    # run scripts according to the OnNodeConfigured -> args 
    find "${TMP_MODULES_DIR}" -type f -name '[0-9][0-9]*.sh' -print0 | sort -z -n | xargs -0 -I '{}' /bin/bash -c '{}' >> /postinstall.log
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh START" >&2
    runScripts
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh: STOP" >&2
}

TMP_MODULES_DIR="/tmp/modules/"
export dna_json="/etc/chef/dna.json"
export host_name=$(hostname -s)
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"
export SLURM_ROOT="/opt/slurm"
export SLURM_ETC="${SLURM_ROOT}/etc"
export compute_instance_type=$(ec2-metadata -t | awk '{print $2}')
#FIXME: do not hardcode.
export SHARED_FS_DIR="/fsx"
#export ec2user_home=$(getent passwd | grep ec2-user | sed 's/^.*:.*:.*:.*:.*:\(.*\):.*$/\1/')
export ec2user_home=$(getent passwd | grep ubuntu | sed 's/^.*:.*:.*:.*:.*:\(.*\):.*$/\1/')
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice/${stack_name}" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
#export ec2user_pass="$(aws secretsmanager get-secret-value --secret-id "${stack_name}" --query SecretString --output text --region "${cfn_region}")"
export ec2user_pass="Succes!2011"

if [[ ${cfn_node_type} == HeadNode ]]; then
    export head_node_hostname=${host_name}
elif [[ ${cfn_node_type} == ComputeFleet ]]; then
    export head_node_hostname=${cfn_head_node}
else
    exit 1
fi

monitoring_dir_name="monitoring"
export monitoring_home="${SHARED_FS_DIR}/${monitoring_dir_name}/${stack_name}"

export myscripts="${@}"

main "$@"