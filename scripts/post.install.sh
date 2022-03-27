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
    
    echo "Getting packages from ${post_install_url}"
    for script in ${myscripts}; do
        aws s3 cp --quiet ${post_install_base}/modules/${script} "${TMP_MODULES_DIR}" --region "${cfn_region}" || exit 1
    done

    chmod 755 -R "${TMP_MODULES_DIR}"*
    # run scripts according to the OnNodeConfigured -> args 
    find "${TMP_MODULES_DIR}" -type f -name '[0-9][0-9]*.sh' -print0 | sort -z -n | xargs -0 -I '{}' /bin/bash -c '{}'
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
export NICE_GPG_KEY_URL=${NICE_GPG_KEY_URL:-"https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY"}
export DCV_KEY_WORD=$(jq --arg default "dcv" -r '.post_install.dcv | if has("dcv_queue_keyword") then .dcv_queue_keyword else $default end' "${dna_json}")
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"
export post_install_url=$(dirname ${cfn_postinstall})
export post_install_base=$(dirname "${post_install_url}")
export SLURM_ROOT="/opt/slurm"
export SLURM_ETC="${SLURM_ROOT}/etc"
export compute_instance_type=$(ec2-metadata -t | awk '{print $2}')
#FIXME: do not hardcode.
export SHARED_FS_DIR="/fsx"
export ec2user_home=$(getent passwd | grep ec2-user | sed 's/^.*:.*:.*:.*:.*:\(.*\):.*$/\1/')
export NICE_ROOT=$(jq --arg default "${SHARED_FS_DIR}/nice" -r '.post_install.enginframe | if has("nice_root") then .nice_root else $default end' "${dna_json}")
export EF_CONF_ROOT=$(jq --arg default "${NICE_ROOT}/enginframe/conf" -r '.post_install.enginframe | if has("ef_conf_root") then .ef_conf_root else $default end' "${dna_json}")
export EF_DATA_ROOT=$(jq --arg default "${NICE_ROOT}/enginframe/data" -r '.post_install.enginframe | if has("ef_data_root") then .ef_data_root else $default end' "${dna_json}")
export CLIENT_BROKER_PORT=$(jq --arg default "8446" -r '.post_install.dcvsm | if has("client_broker_port") then .client_broker_port else $default end' "${dna_json}")
export AGENT_BROKER_PORT=$(jq --arg default "8445" -r '.post_install.dcvsm | if has("agent_broker_port") then .agent_broker_port else $default end' "${dna_json}")
export BROKER_CA=$(jq --arg default "${ec2user_home}/dcvsmbroker_ca.pem" -r '.post_install.dcvsm | if has("broker_ca") then .broker_ca else $default end' "${dna_json}")
export ec2user_pass="$(aws secretsmanager get-secret-value --secret-id "${stack_name}" --query SecretString --output text --region "${cfn_region}")"

if [[ ${cfn_node_type} == HeadNode ]]; then
    export head_node_hostname=${host_name}
elif [[ ${cfn_node_type} == ComputeFleet ]]; then
    export head_node_hostname=${cfn_head_node}
else
    exit 1
fi

monitoring_dir_name="monitoring"
export monitoring_home="${SHARED_FS_DIR}/${monitoring_dir_name}/${head_node_hostname}"

export myscripts="${@}"

main "$@"