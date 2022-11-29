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
    for script in "${@}"; do
        aws s3 cp --quiet ${post_install_base}/modules/${script} "${TMP_MODULES_DIR}" --region "${cfn_region}" || exit 1
    done

    chmod 755 -R "${TMP_MODULES_DIR}"*
    find "${TMP_MODULES_DIR}" -type f -name '[0-9][0-9]*.sh' -print0 | sort -z -n | xargs -0 -I '{}' /bin/bash -c '{}'
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh START" >&2
    runScripts "${@}"
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] post.install.sh: STOP" >&2
}

TMP_MODULES_DIR="/tmp/modules/"
export host_name=$(hostname -s)
export SLURM_CONF_FILE="/opt/slurm/etc/pcluster/slurm_parallelcluster_*_partition.conf"
post_install_url=$(dirname ${cfn_postinstall})
export post_install_base=$(dirname "${post_install_url}")
SLURM_ROOT="/opt/slurm"
export SLURM_ETC="${SLURM_ROOT}/etc"
export SHARED_FS_DIR="$(cat /etc/parallelcluster/shared_storages_data.yaml | grep mount_dir | awk '{print $2}')"
export NICE_ROOT="${SHARED_FS_DIR}/nice"
export EF_CONF_ROOT="${NICE_ROOT}/enginframe/conf"
export EF_DATA_ROOT="${NICE_ROOT}/enginframe/data"

if [[ ${cfn_node_type} == HeadNode ]]; then
    export head_node_hostname=${host_name}
elif [[ ${cfn_node_type} == ComputeFleet ]]; then
    export head_node_hostname=${cfn_head_node}
else
    exit 1
fi

main "${@}"