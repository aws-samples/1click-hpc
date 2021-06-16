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


export SLURM_ROOT="/opt/slurm"
export SLURM_ETC="${SLURM_ROOT}/etc"

set -x
set -e


configureSACCT() {
    if [[ ${proto} == "https://" ]]; then
        wget -nv -P "${SLURM_ETC}/" "${post_install_base}/scripts/prologSlurmctld.sh" || exit 1
    elif [[ ${proto} == "s3://" ]]; then
        aws s3 cp "${post_install_base}/scripts/prologSlurmctld.sh" "${SLURM_ETC}/" --region "${cfn_region}" || exit 1
    else
        exit 1
    fi
    
    chmod +x "${SLURM_ETC}/prologSlurmctld.sh"
    
    echo "PrologSlurmctld=/opt/slurm/etc/prologSlurmctld.sh" >> "${SLURM_ETC}/slurm.conf"
}

restartSlurmDaemons() {
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] configure.slurm.tagging.master: START" >&2
    configureSACCT
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] configure.slurm.tagging.master: STOP" >&2
}

main "$@"