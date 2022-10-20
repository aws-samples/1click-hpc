#!/bin/bash

echo "#######################" >> /fsx/shared/debug.log
date >> /fsx/shared/debug.log
echo "${SLURM_JOB_USER}" >> /fsx/shared/debug.log
echo "${SLURM_JOBID}" >> /fsx/shared/debug.log

#slurm directory
export SLURM_ROOT=/opt/slurm
echo "${SLURM_JOB_USER}" >> /tmp/jobs/jobs_users
echo "${SLURM_JOBID}" >> /tmp/jobs/jobs_ids

#load the comment of the job.
sleep $((RANDOM % 5))
Project=$($SLURM_ROOT/bin/scontrol show job ${SLURM_JOB_ID} | grep Comment | awk -F'=' '{print $2}')
Project_Tag=""
if [ ! -z "${Project}" ];then
echo "${Project}" >> /tmp/jobs/jobs_projects
fi

#make enroot folders to accomodate multiple users on same compute host

runtime_path=$(echo "/run/enroot/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$runtime_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$runtime_path"
chmod 0700 "$runtime_path"

cache_path=$(echo "/tmp/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$cache_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$cache_path"
chmod 0770 "$cache_path"

data_path=$(echo "/tmp/enroot-data/user-$(id -u ${SLURM_JOB_USER})")
mkdir -p "$data_path"
chown "$SLURM_JOB_UID:$(id -g "$SLURM_JOB_UID")" "$data_path"
chmod 0700 "$data_path"


#kill all stray processes on the allocated GPUS
awk_ndx=1
procs=$(nvidia-smi)
while [ 1 -eq 1 ]; do
  gpu=`echo $SLURM_JOB_GPUS | awk '{ print $n }' n=$awk_ndx FS=","`
  [ "$gpu" = "" ] && break
  echo "killing stray processes found on gpu $gpu" >> /fsx/shared/debug.log
  kill $(echo "$procs" | awk '$2=="Processes:" {p=1} p && $2 == "'"$gpu"'" && $5 > 0 {print $5}') &>> /fsx/shared/debug.log
  awk_ndx=`expr $awk_ndx + 1`
done

if [ $SLURM_JOB_GPUS == '0,1,2,3,4,5,6,7' ] && [ $Project != 'defective' ]; then
    echo "Test nccl and EFA" >> /fsx/shared/debug.log
    results='0,0,0,0,0,0,0,0'
    instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    ipaddr=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

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
    export SLURM_NODELIST=$SLURMD_NODENAME

    MPI_ARGS="-np 8 --map-by ppr:8:node -bind-to numa --allow-run-as-root"
    ENVIRON_VARS="-x LD_LIBRARY_PATH -x NCCL_SHM_DISABLE=1 -x NCCL_P2P_DISABLE=1 -x NCCL_NET_GDR_LEVEL=SYS"
    NCCL_ARGS="-b 500M -f 2 -g 1 -e 1G -n 50 -w 10"

    source /etc/profile.d/modules.sh
    module load cuda/11.6

    function die() {
        echo "$*" >> /fsx/shared/debug.log
        echo "nccl tests died" >> /fsx/shared/debug.log
        #exit 1
        # failed node, arrest it with service job, cancel initial job
        return results
    }
    function log() {
        echo "$*" >> /fsx/shared/debug.log
        echo "nccl tests logged" >> /fsx/shared/debug.log
    }
    function dbg() {
        echo "$*" >> /fsx/shared/debug.log
        echo "nccl tests debugged" >> /fsx/shared/debug.log
        #todo: add here new results based on defect types
    }

    function collect_nccl_allreduce_ib_loopback_data() {
        nccl_allreduce_ib_loopback_out=$(/opt/amazon/openmpi/bin/mpirun --oversubscribe $MPI_ARGS $ENVIRON_VARS all_reduce_perf $NCCL_ARGS)
        nccl_allreduce_ib_loopback_out_rc=$?
        if [[ $nccl_allreduce_ib_loopback_out_rc != 0 ]]; then
            log "nccl_allreduce_ib_loopback_freq_out"
            die 1 "$FUNCNAME: nccl_allreduce (IB loopback) returned error code $nccl_allreduce_ib_loopback_out_rc"
            results='1,1,1,1,1,1,1,1'
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
                dbg "Measured Avg NCCL allreduce ib loopback bus BW $avg_bus_bw GB/s"
                break
            fi
        done
        dbg "Measured Avg NCCL allreduce IB loopback bus BW=$avg_bus_bw, Expected NCCL allreduce IB loopback BW=$EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW"
        if [[ $avg_bus_bw < $EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW ]]
        then
            log "$nccl_allreduce_ib_loopback_out"
            die 1 "$FUNCNAME: NCCL allreduce IB loopback, BUS BW (expected > $EXP_NCCL_ALLREDUCE_IB_LOOPBACK_BW GB/s, but measured $avg_bus_bw GB/s"
            return 1
        fi
    }
    check_nccl_allreduce_ib_loopback

    serials=$(nvidia-smi --query-gpu="serial" --format=csv,noheader | tr '\n' ',' | sed 's/.$//')

    # results="r0,r1,r2,r3,r4,r5,r6,r7" in the format 0 if healthy, 1 if slow nccl, 2 ecc defect, 3 unresponsive
    dbhost=$(awk -F "=" '/host/ {print $2}' /root/.my.cnf | /usr/bin/xargs)
    password=$(awk -F "=" '/password/ {print $2}' /root/.my.cnf | /usr/bin/xargs)
    database=$(awk -F "=" '/database/ {print $2}' /root/.my.cnf | /usr/bin/xargs)
    awk_ndx=1
    while [ 1 -eq 1 ]; do
        result=$(echo $results | awk '{ print $n }' n=$awk_ndx FS=",")
        gpusn=$(echo $serials | awk '{ print $n }' n=$awk_ndx FS=",")
        gpuid=$(echo $SLURM_JOB_GPUS | awk '{ print $n }' n=$awk_ndx FS=",")
        [ "$result" = "" ] && break
        /usr/bin/mysql --host=$dbhost --user=admin --password=$password --database=$database --batch -e "call RecordGPUhealth('$gpusn','$SLURM_CLUSTER_NAME','$SLURMD_NODENAME',$gpuid,'$instanceid','$ipaddr',$result)"
        awk_ndx=`expr $awk_ndx + 1`
    done

    if [ "$result" != '0,0,0,0,0,0,0,0' ]; then
        /opt/slurm/bin/sbatch --nodelist $SLURMD_NODENAME --comment defective /opt/slurm/sbin/debug.sbatch
        /opt/slurm/bin/scancel ${SLURM_JOBID}
        echo "prolog script cancelled job ${SLURM_JOBID}" >> /fsx/shared/debug.log
    fi
fi

# place this snippet at the end of prolog.sh in /opt/slurm/sbinexit