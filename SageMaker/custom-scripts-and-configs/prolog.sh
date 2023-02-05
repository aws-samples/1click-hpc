#!/bin/bash

#slurm directory
export SLURM_ROOT=/opt/slurm
mkdir -p /root/jobs

if [ -z "${CUDA_VISIBLE_DEVICES}" ]; then
    > /root/jobs/jobs_users
    > /root/jobs/jobs_ids
    > /root/jobs/jobs_projects
fi

echo "${SLURM_JOB_USER}" >> /root/jobs/jobs_users
echo "${SLURM_JOBID}" >> /root/jobs/jobs_ids

#load the comment of the job.
#Project=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Comment | awk -F'=' '{print $2}')
Project=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Account | awk -F' |=' '{print $9}')
if [ ! -z "${Project}" ];then
    echo "${Project}" >> /root/jobs/jobs_projects
fi

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

#kill all stray processes on the allocated GPUS
awk_ndx=1
procs=$(nvidia-smi)
gpus="$SLURM_JOB_GPUS"
if [ -z "$gpus" ]; then
  gpus="0,1,2,3,4,5,6,7"
fi
while [ 1 -eq 1 ]; do
  gpu=`echo $gpus | awk '{ print $n }' n=$awk_ndx FS=","`
  [ "$gpu" = "" ] && break
  echo "killing stray processes found on gpu $gpu"
  kill $(echo "$procs" | awk '$2=="Processes:" {p=1} p && $2 == "'"$gpu"'" && $5 > 0 {print $5}') 2>/dev/null
  awk_ndx=`expr $awk_ndx + 1`
done

timestamp=$(date +%s)
#send datadog event for job start
# Curl command
curl -X POST "https://api.datadoghq.com/api/v1/events" \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
-H "DD-API-KEY: yourapikey" \
-d @- << EOF
{
  "title": "Slurm Job Starting",
  "text": "slurm job started",
  "aggregation_key": "SageMaker SLURM",
  "date_happened": ${timestamp},
  "tags": [
    "hpcuser:${SLURM_JOB_USER}",
    "slurmjob:${SLURM_JOBID}",
    "project:${Project}"
  ]
}
EOF