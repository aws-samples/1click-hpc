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

SLURM_RESUME_CONF_FILE="/etc/parallelcluster/slurm_plugin/parallelcluster_slurm_resume.conf"

set -x
set -e

#ADD All or Nothing to the Slurm conf
addAllOrNothingtoSlurmConf() {
    echo "all_or_nothing_batch = True" >> "${SLURM_RESUME_CONF_FILE}"
}

restartSlurmDaemon() {
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 04.configure.slurm.AllOrNothing.headnode.sh: START" >&2
    addAllOrNothingtoSlurmConf
    restartSlurmDaemon
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 04.configure.slurm.AllOrNothing.headnode.sh: STOP" >&2
}

main "$@"