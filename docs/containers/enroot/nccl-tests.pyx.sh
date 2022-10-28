#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --job-name=nccl-tests
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --exclusive
#SBATCH --comment "stability"
#SBATCH --output=%x_%j.out
module load openmpi
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib:/opt/amazon/openmpi/lib
export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin:/opt/slurm/bin
export FI_EFA_FORK_SAFE=1
export FI_LOG_LEVEL=1
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export FI_EFA_ENABLE_SHM_TRANSFER=0
export FI_PROVIDER=efa
export FI_EFA_TX_MIN_CREDITS=64
export NCCL_DEBUG=warn
export NCCL_PROTO=simple
export NCCL_TREE_THRESHOLD=0
export OMPI_MCA_mtl_base_verbose=1
export OMPI_MCA_btl="^openib"
export OMPI_DIR=/opt/amazon/openmpi
export PMIX_MCA_gds=hash

srun --comment stability --container-image=public.ecr.aws\#w6p6i9i7/aws-efa-nccl-rdma:base-cudnn8-cuda11.3-ubuntu20.04 \
    --container-mounts=/opt/slurm:/opt/slurm/ /opt/nccl-tests/build/all_reduce_perf -b 128M -e 8G -f 2 -g 1 -c 1 -n 20