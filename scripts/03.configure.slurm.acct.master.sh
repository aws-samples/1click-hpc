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

installPreReq() {
    yum -y install mysql
}


configureSACCT() {
    if [[ ${proto} == "https://" ]]; then
        wget -nv -P /tmp/ "${post_install_base}/sacct/mysql/db.config" || exit 1
        wget -nv -P /tmp/ "${post_install_base}/sacct/mysql/grant.mysql" || exit 1
        wget -nv -P /tmp/ "${post_install_base}/sacct/slurm/slurmdbd.conf" || exit 1
        wget -nv -P /tmp/ "${post_install_base}/sacct/slurm/slurm_sacct.conf" || exit 1

    elif [[ ${proto} == "s3://" ]]; then
        aws s3 cp "${post_install_base}/sacct/mysql/db.config" /tmp/ || exit 1
        aws s3 cp "${post_install_base}/sacct/mysql/grant.mysql" /tmp/ || exit 1
        aws s3 cp "${post_install_base}/sacct/slurm/slurmdbd.conf" /tmp/ || exit 1
        aws s3 cp "${post_install_base}/sacct/slurm/slurm_sacct.conf" /tmp/ || exit 1
    else
        exit 1
    fi
    
    export HEAD_NODE=$(hostname -s)
    /usr/bin/envsubst < slurmdbd.conf > "${SLURM_ETC}/slurmdbd.conf"
    /usr/bin/envsubst < slurm_sacct.conf > "${SLURM_ETC}/slurm_sacct.conf"
    
    mysql --defaults-extra-file="db.config" < "grant.mysql"
    echo "include slurm_sacct.conf" >> "${SLURM_ETC}/slurm.conf"
}

restartSlurmDaemons() {
    $SLURM_ROOT/sbin/slurmdbd
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] configure.slurm.acct.master: START" >&2
    installPreReq
    configureSACCT
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] configure.slurm.acct.master: STOP" >&2
}

main "$@"