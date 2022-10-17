#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=defective
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --output=%x_%j.out
#SBATCH --comment=defect

srun --comment defect /opt/slurm/sbin/report.sh

# place this file in /opt/slurm/sbin
