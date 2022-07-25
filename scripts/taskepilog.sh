#!/bin/bash

#FIXME: do not hardcode.
export SHARED_FS_DIR="/fsx"
monitoring_dir_name="monitoring"
prefix="parallelcluster-"
string=${SLURM_CLUSTER_NAME}
#remove prefix from string
stack_name=${string#"$prefix"}
monitoring_home="${SHARED_FS_DIR}/${monitoring_dir_name}/${stack_name}"

#get compute instance type
compute_instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type)
gpu_instances="[pg][2-9].*\.[0-9]*[x]*large"
if [[ $compute_instance_type =~ $gpu_instances ]]; then
    /usr/local/bin/docker-compose -f "${monitoring_home}/docker-compose/docker-compose.compute.gpu.yml" -p monitoring-compute down
else
    /usr/local/bin/docker-compose -f "${monitoring_home}/docker-compose/docker-compose.compute.yml" -p monitoring-compute down
fi