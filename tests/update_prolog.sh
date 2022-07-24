#!/bin/bash
# make a hostfile with all the compute nodes that are running

pscp.pssh -vA -h hostfile -p 5 -e /tmp /opt/slurm/etc/prolog.sh /tmp

pssh -h hostfile -i "sudo cp /tmp/prolog.sh /opt/slurm/etc"

pssh -h hostfile -i "sudo systemctl restart slurmd"

sudo systemctl restart slurmctld