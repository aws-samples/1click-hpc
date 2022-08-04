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

set -x
set -e

configureSACCT() {
    # Set variables from post-install args
    secret_id=$1
    rds_endpoint=$2
    rds_port=$3

    mkdir -p /tmp/slurm_accounting
    pushd /tmp/slurm_accounting

cat <<EOF > sacct_attrs.json
{
"slurm_accounting": {
"secret_id": "${secret_id}",
"rds_endpoint": "${rds_endpoint}",
"rds_port": "${rds_port}"}
}
EOF

    jq -s '.[0] * .[1]' /etc/chef/dna.json sacct_attrs.json > dna_combined.json

    # Copy Slurm configuration files
    source_path=https://raw.githubusercontent.com/aws-samples/pcluster-manager/main/resources/files
    files=(slurm_sacct.conf.erb slurmdbd.service slurmdbd.conf.erb  slurm_accounting.rb)
    for file in "${files[@]}"
    do
        wget -qO- ${source_path}/sacct/${file} > ${file}
    done

    sudo cinc-client \
    --local-mode \
    --config /etc/chef/client.rb \
    --log_level auto \
    --force-formatter \
    --no-color \
    --chef-zero-port 8889 \
    -j dna_combined.json \
    -z slurm_accounting.rb

    # FIXME: make idempotent?
    sleep 5
    set +e
    /opt/slurm/bin/sacctmgr -i create cluster ${stack_name}
    /opt/slurm/bin/sacctmgr -i create account name=none
    /opt/slurm/bin/sacctmgr -i create user ${cfn_cluster_user} cluster=${stack_name} account=none
    
}

restartSlurmDaemons() {
    systemctl restart slurmctld
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.aws.slurm.acct.headnode.sh: START" >&2
    configureSACCT
    restartSlurmDaemons
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 03.configure.aws.slurm.acct.headnode.sh: STOP" >&2
}

main "$@"