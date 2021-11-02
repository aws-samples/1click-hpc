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
source /etc/parallelcluster/cfnconfig

#slurm directory
SLURM_ROOT="/opt/slurm"

#function used to convert the hostname to ip
function nametoip()
{
    instance_ip=$(nslookup $1)
    echo "${instance_ip}" | awk '/^Address: / { print $2 }'
}

#load the comments of the job.
#this is the supported format: Key=aws-tag1,Value=tag-value1 Key=aws-tag2,Value=tag-value2
tags=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Comment  | sed 's/Comment=//' | sed 's/^ *//g')


#expand the hostnames
hosts=$($SLURM_ROOT/bin/scontrol show hostnames ${SLURM_NODELIST})

instance_id_list=""
#verify each host
for host in $hosts
  do
   private_ip=$(nametoip $host)
   #verify if the instance is running
   result=$(aws ec2 --region $cfn_region describe-instances --filters "Name=network-interface.addresses.private-ip-address,Values=${private_ip}" --query Reservations[*].Instances[*].InstanceId --output text)
   if [ ! -z "${result}" ];then
     num_jobs=$($SLURM_ROOT/bin/squeue -h -w ${host} | wc -l)
     if [ "${num_jobs}" -eq 1 ];then
       instance_id_list="${instance_id_list} ${result}"
     fi
   fi
done

#fix this
for host in $instance_id_list
do
  #consider API throttling 
  aws ec2 create-tags --region $cfn_region --resources ${host} --tags Key=aws-parallelcluster-username,Value=${SLURM_JOB_USER} Key=aws-parallelcluster-jobid,Value=${SLURM_JOBID} Key=aws-parallelcluster-partition,Value=${SLURM_JOB_PARTITION} ${tags}
done

exit 0