#!/bin/bash

echo "print ================ Running prolog ==============="
echo "print nodes_list: $SLURM_JOB_NODELIST"
echo "print num nodes: $SLURM_NNODES"

base_name=$(echo "$SLURM_JOB_NODELIST" | cut -d'[' -f 1)

for i in $(seq 1 "$SLURM_NNODES");
do
  echo "print slurm_node: $base_name$i"
  ### Enable Persistent Mode in all GPUs ###
  sudo -u root nvidia-smi -pm 1
  ### Create a group with all GPUs in the node
  group=$(sudo -u "$SLURM_JOB_USER" dcgmi group --host "$base_name$i" -c allgpus --default)
  if [ $? -eq 0 ]; then
    ### Get the created GroupID ###
    groupid=$(echo "$group" | awk '{print $10}')
    export dcgm_group_id=groupid
    ### Enable DCGM Health Monitoring ###
    ### This enables monitoring of all watches - PCIe, memory, infoROM, thermal and power and NVLink.
    sudo -u "$SLURM_JOB_USER" dcgmi health --host "$base_name$i" -g "$groupid" -s a
    ### Enable DCGM Statistics ###
    ### This watches all the relevant metrics periodically
    sudo -u "$SLURM_JOB_USER" dcgmi stats --host "$base_name$i" -g "$groupid" --enable
    ### Add Configurations ###
    ### This enable/disables settings like Sync Boost, Target clocks, ECC Mode, Power Limit and Compute Mode
    sudo -u "$SLURM_JOB_USER" dcgmi config --host "$base_name$i" -g "$groupid" --set -s 1 -e 1 -c 0
    ### Add Policies ###
    ### This sets actions and validations for events like PCIe/NVLINK Errors, ECC Errors, Page Retirement Limit,
    ### Power Excursions, Thermal Excursions and XIDs
    sudo -u "$SLURM_JOB_USER" dcgmi policy --host "$base_name$i" -g "$groupid" --set 1,1 -x -n -p -e -T 80 -P 270
    ### Run a quick invasive Health Check ###
    sudo -u "$SLURM_JOB_USER" dcgmi diag --host "$base_name$i" -g "$groupid" -r 1
    ### Start Recording Statistics ###
    sudo -u "$SLURM_JOB_USER" dcgmi stats --host "$base_name$i" -g "$groupid" -s "$SLURM_JOBID"
    ### Register Policy and Start listening for violations
    sudo -u "$SLURM_JOB_USER" dcgmi policy --host "$base_name$i" -g "$groupid" --reg &
  fi
done