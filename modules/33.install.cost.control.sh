#!/bin/bash

# MIT No Attribution
# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


source "/etc/parallelcluster/cfnconfig"

configureCostControl(){

    if [ "${cfn_node_type}" == "ComputeFleet" ];then

        # Create the folder used to save jobs information

        mkdir -p /root/jobs

        # Configure the script to run every minute
        echo "
* * * * * /opt/slurm/sbin/check_tags.sh
" | crontab -

    else
        # Cron script used to update the instance tags

        cat <<'EOF' > /opt/slurm/sbin/check_tags.sh
#!/bin/bash

source /etc/profile
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
region=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v -s http://169.254.169.254/latest/meta-data/placement/region)
aws configure set region $region

update=0
sleep $[ ( $RANDOM % 30 ) + 1 ]s

# get current jobs on this node
host=$(hostname)
current=$(squeue -w "$host" -h -o%i,%a,%u,%t | awk '$4 == "R" split($1,a,",") split(a[1],b,"_"); {print b[1] "|" a[2] "|" a[3]}' | sort | uniq)
saved=""
if [ -f /root/jobs/combined ]; then
    saved=$(cat /root/jobs/combined)
else
    > /root/jobs/combined
fi

if [ "$saved" != "$current" ]; then
    # need to tag the node
    active_users=$(echo "$current" | cut -d"|" -f3 | sort | uniq | head -c -1 | tr "\n" "_")
    active_jobs=$(echo "$current" | cut -d"|" -f1 | sort | uniq | head -c -1 | tr "\n" "_")
    active_projects=$(echo "$current" | cut -d"|" -f2 | sort | uniq | head -c -1 | tr "\n" "_")

    # save the current tagging
    echo "$current" > /root/jobs/combined
    update=1
fi

if [ ${update} -eq 1 ]; then

# Instance ID
MyInstID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v -s http://169.254.169.254/latest/meta-data/instance-id)
tag_project=$(cat /tmp/jobs/tag_project)
aws ec2 create-tags --resources ${MyInstID} --tags Key=aws-parallelcluster-username,Value="${active_users}"
aws ec2 create-tags --resources ${MyInstID} --tags Key=aws-parallelcluster-jobid,Value="${active_jobs}"
aws ec2 create-tags --resources ${MyInstID} --tags Key=aws-parallelcluster-project,Value="${active_projects}"

fi
EOF

        chmod +x /opt/slurm/sbin/check_tags.sh
        
        # Create Prolog and Epilog to tag the instances
        # This will overwrite 07.configure.slurm.prologs.headnode.sh for prolog and epilog
        cat <<'EOF' > /opt/slurm/sbin/prolog.sh
#!/bin/bash

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

EOF

        cat <<'EOF' > /opt/slurm/sbin/epilog.sh
#!/bin/bash
#slurm directory
export SLURM_ROOT=/opt/slurm
EOF
        chmod +x /opt/slurm/sbin/prolog.sh
        chmod +x /opt/slurm/sbin/epilog.sh

        # Configure slurm to use Prolog and Epilog
        echo "PrologFlags=Alloc" >> /opt/slurm/etc/slurm.conf
        echo "Prolog=/opt/slurm/sbin/prolog.sh" >> /opt/slurm/etc/slurm.conf
        echo "Epilog=/opt/slurm/sbin/epilog.sh" >> /opt/slurm/etc/slurm.conf

        systemctl restart slurmctld

    fi
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 33.install.cost.control.sh: START" >&2
    configureCostControl
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 33.install.cost.control.sh.sh: STOP" >&2
}

main "$@"