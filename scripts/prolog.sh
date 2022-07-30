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


# The script assigns the required tags to the EC2 instances of the jobs.
set -e

source /etc/parallelcluster/cfnconfig

#make enroot folders to accomodate multiple users on same compute host

runtime_path=$(echo "/run/enroot/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$runtime_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$runtime_path"
chmod 0700 "$runtime_path"

cache_path=$(echo "/tmp/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$cache_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$cache_path"
chmod 0770 "$cache_path"

data_path=$(echo "/tmp/enroot-data/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$data_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$data_path"
chmod 0700 "$data_path"

#to add job comment here
tags=""

host=$(curl http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --region $cfn_region --resources ${host} --tags Key=aws-parallelcluster-username,Value=${SLURM_JOB_USER} Key=aws-parallelcluster-jobid,Value=${SLURM_JOBID} Key=aws-parallelcluster-partition,Value=${SLURM_JOB_PARTITION} ${tags}

exit 0