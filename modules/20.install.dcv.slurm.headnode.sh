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


# Add "dcv2" requirements on the DCV nodes.

set -x
set -e

DCV_KEY_WORD="dcv"

#ADD DCV as a features to Slurm Partitions
addDCVtoSlurmPartitions() {
    for conf_file in $(ls ${SLURM_CONF_FILE} | grep "${DCV_KEY_WORD}"); do
        sed -i 's/Feature=/Feature=dcv2,/g' "${conf_file}"
    done
}

restartSlurmDaemon() {
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 20.install.dcv.slurm.headnode.sh: START" >&2
    addDCVtoSlurmPartitions
    restartSlurmDaemon
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 20.install.dcv.slurm.headnode.sh: STOP" >&2
}

main "$@"
