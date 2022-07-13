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

# fix cuda in containers
/sbin/modprobe nvidia

if [ "$?" -eq 0 ]; then
  # Count the number of NVIDIA controllers found.
  NVDEVS=`lspci | grep -i NVIDIA`
  N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
  NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`

  N=`expr $N3D + $NVGA - 1`
  for i in `seq 0 $N`; do
    mknod -m 666 /dev/nvidia$i c 195 $i
  done

  mknod -m 666 /dev/nvidiactl c 195 255

else
  exit 1
fi

/sbin/modprobe nvidia-uvm

if [ "$?" -eq 0 ]; then
  # Find out the major device number used by the nvidia-uvm driver
  D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`

  mknod -m 666 /dev/nvidia-uvm c $D 0
else
  exit 1
fi

#make enroot folders to accomodate multiple users on same compute host

runtime_path="$(sudo -u "$SLURM_JOB_USER" sh -c 'echo "/run/enroot/user-$(id -u)"')"
mkdir -p "$runtime_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$runtime_path"
chmod 0700 "$runtime_path"

cache_path="$(sudo -u "$SLURM_JOB_USER" sh -c 'echo "/tmp/group-$(id -g)"')"
mkdir -p "$cache_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$cache_path"
chmod 0770 "$cache_path"

data_path="$(sudo -u "$SLURM_JOB_USER" sh -c 'echo "/tmp/enroot-data/user-$(id -u)"')"
mkdir -p "$data_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$data_path"
chmod 0700 "$data_path"

exit 0