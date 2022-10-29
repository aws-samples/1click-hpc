#!/bin/bash
# Single node NCCL test POC, enforcing NCCL over EFA instead of internal switch

export LD_LIBRARY_PATH=/opt/amazon/openmpi/lib64:/opt/amazon/efa/lib64
export PATH=/opt/amazon/efa/bin:$PATH
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export FI_PROVIDER=efa
export NCCL_SHM_DISABLE=1
export NCCL_P2P_DISABLE=1

MPI_ARGS="-np 8 --allow-run-as-root"
NCCL_ARGS="-b 500M -f 2 -g 1 -e 1G -n 50 -w 10"

module load cuda/11.6

/opt/amazon/openmpi/bin/mpirun $MPI_ARGS all_reduce_perf $NCCL_ARGS