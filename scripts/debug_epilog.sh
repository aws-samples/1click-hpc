#!/bin/bash

echo "print ================ Running epilog ==============="

echo "print nodes_list: $SLURM_JOB_NODELIST"
echo "print num nodes: $SLURM_NNODES"

base_name=$(echo "$SLURM_JOB_NODELIST" | cut -d'[' -f 1)

for i in $(seq 1 "$SLURM_NNODES");
do
  echo "print slurm_node: $base_name$i"
  ### Get GroupID ###
  groupid=$(sudo -u "$SLURM_JOB_USER" dcgmi group --host "$base_name$i" -l | awk 'FNR == 14 {print $3}')
  ### Stop Recording Statistics ###
  sudo -u "$SLURM_JOB_USER" dcgmi stats --host "$base_name$i" -x "$SLURM_JOBID"
  ### Display Statistics ###
  sudo -u "$SLURM_JOB_USER" dcgmi stats --host "$base_name$i" -v -j "$SLURM_JOBID"
  ### Delete Group ###
  sudo -u "$SLURM_JOB_USER" dcgmi group --host "$base_name$i" -d "$groupid"
done