#!/bin/bash

# Single node NCCL test POC, enforcing NCCL over EFA instead of internal switch

export LD_LIBRARY_PATH=/opt/amazon/openmpi/lib64:/opt/amazon/efa/lib64
export PATH=/opt/amazon/efa/bin:$PATH
export FI_EFA_FORK_SAFE=1
export FI_LOG_LEVEL=1
export FI_EFA_USE_DEVICE_RDMA=1 # use for p4dn
export NCCL_DEBUG=info
export OMPI_MCA_mtl_base_verbose=1
export FI_EFA_ENABLE_SHM_TRANSFER=0
export FI_PROVIDER=efa
export FI_EFA_TX_MIN_CREDITS=64
export EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW=5
export SLURM_TASKS_PER_NODE=1
export SLURM_NODELIST=localhost

MPI_ARGS="-np 8 --map-by ppr:8:node -bind-to numa --allow-run-as-root"
ENVIRON_VARS="-x LD_LIBRARY_PATH -x NCCL_SHM_DISABLE=1 -x NCCL_P2P_DISABLE=1 -x NCCL_NET_GDR_LEVEL=SYS"
NCCL_ARGS="-b 500M -f 2 -g 1 -e 1G -n 50 -w 10"

#module load cuda/11.4
module load cuda/11.6

function collect_nccl_allreduce_ib_loopback_data() {
    nccl_allreduce_ib_loopback_out=$(/opt/amazon/openmpi/bin/mpirun --oversubscribe $MPI_ARGS $ENVIRON_VARS all_reduce_perf $NCCL_ARGS)
    nccl_allreduce_ib_loopback_out_rc=$?
    if [[ $nccl_allreduce_ib_loopback_out_rc != 0 ]]; then
        echo "nccl_allreduce_EFA_loopback_freq_out"
        echo "$FUNCNAME: nccl_allreduce (EFA loopback) returned error code $nccl_allreduce_ib_loopback_out_rc"
    fi
    IFS=$'\n'
    nccl_allreduce_ib_loopback_out_lines=( $nccl_allreduce_ib_loopback_out )
    IFS=$' \t\n'
}

function check_nccl_allreduce_ib_loopback() {
    collect_nccl_allreduce_ib_loopback_data

    for ((i=0; i<${#nccl_allreduce_ib_loopback_out_lines[*]}; i++))
    do
        if [[ "${nccl_allreduce_ib_loopback_out_lines[$i]//bandwidth}" != "${nccl_allreduce_ib_loopback_out_lines[$i]}" ]]
        then
            IFS=$' \t\n'
            nccl_allreduce_ib_loopback_out_line=( ${nccl_allreduce_ib_loopback_out_lines[$i]} )
            avg_bus_bw=${nccl_allreduce_ib_loopback_out_line[5]}
            echo "Measured Avg NCCL allreduce EFA loopback bus BW $avg_bus_bw GB/s"
            break
        fi
    done
    echo "Measured Avg NCCL allreduce EFA loopback bus BW=$avg_bus_bw, Expected NCCL allreduce EFA loopback BW=$EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW"
    if [[ $avg_bus_bw < $EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW ]]
    then
        echo "$nccl_allreduce_ib_loopback_out"
        echo "$FUNCNAME: NCCL allreduce EFA loopback, BUS BW (expected > $EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW GB/s, but measured $avg_bus_bw GB/s"
    fi
}

check_nccl_allreduce_ib_loopback
