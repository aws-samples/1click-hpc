# make a hostfile with all the compute nodes that are running

pscp.pssh -vA -h hostfile -p 5 -e /tmp /opt/slurm/etc/slurm.conf /tmp

pssh -h hostfile -i "sudo cp /tmp/slurm.conf /opt/slurm/etc"

pssh -h hostfile -i "sudo systemctl restart slurm*"

sudo systemctl restart slurm*
