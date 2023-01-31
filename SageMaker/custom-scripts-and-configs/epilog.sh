#!/bin/bash
#slurm directory
export SLURM_ROOT=/opt/slurm
if [ -f /root/jobs/jobs_users ]; then 
    sed -i "0,/${SLURM_JOB_USER}/d" /root/jobs/jobs_users
fi
if [ -f /root/jobs/jobs_ids ]; then
    sed -i "0,/${SLURM_JOBID}/d" /root/jobs/jobs_ids
fi

#load the comment of the job.
#Project=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Comment | awk -F'=' '{print $2}')
Project=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Account | awk -F' |=' '{print $9}')
if [ ! -z "${Project}" ];then
    sed -i "0,/${Project}/d" /root/jobs/jobs_projects
fi

