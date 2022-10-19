#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=defective_node
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --output=/fsx/shared/%x_%j.out
#SBATCH --comment=defect

/opt/slurm/bin/srun --comment defective /opt/slurm/sbin/report.sh

# place this file in /opt/slurm/sbin
