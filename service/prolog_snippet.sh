if [ $SLURM_JOB_GPUS == '0,1,2,3,4,5,6,7' ]; then
    cluster="$SLURM_CLUSTER_NAME"
    jobid="$SLURM_JOB_ID"
    host="$SLURMD_NODENAME"
    instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    ipaddr=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    #echo "$cluster - $host - $instanceid - $ipaddr - $jobid" >> /fsx/shared/debug.log

    defect=0
#----------------------------------------------
#TODO: test the node and output these variables
#----------------------------------------------
    # serials='sn0,sn1,sn2,sn3,sn4,sn5,sn6,sn7'
    # results="r0,r1,r2,r3,r4,r5,r6,r7" in the format 0 if healthy, 1 if defect
    while [ 1 -eq 1 ]; do
        result=`echo $results | awk '{ print $n }' n=$awk_ndx FS=","`
        gpusn=`echo $serials | awk '{ print $n }' n=$awk_ndx FS=","`
        gpuid=`echo $SLURM_JOB_GPUS | awk '{ print $n }' n=$awk_ndx FS=","`
        [ "$result" = "" ] && break
        mysql --batch -e "call RecordGPUhealth('$gpusn','$cluster','$host',$gpuid,'$instanceid','$ipaddr',$result)"
        defect=$($defect + $result)
        awk_ndx=`expr $awk_ndx + 1`
    done
    
    if [ $defect -gt 0 ]; then
        sbatch --nodelist $host --comment defect /opt/slurm/sbin/debug.sbatch $result
        /opt/slurm/bin/scancel $jobid
        echo "prolog script cancelled job $jobid" >> /fsx/shared/debug.log
    fi
fi

# place this snippet at the end of prolog.sh in /opt/slurm/sbin