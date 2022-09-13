#!/bin/bash

# use the ideas from https://swsmith.cc/posts/slurm-login-aws-parallelcluster.html
# make an AMI from the headnode (172.31.36.138)
# then spin up a new instance with that AMI and do:

systemctl disable slurmctld
systemctl disable slurmdbd

rm -rf /opt/slurm
rm -rf /home/*
rm -f /etc/systemd/system/slurmdbd.service
rm -f /etc/systemd/system/slurmctld.service

mkdir -p /opt/slurm
mkdir -p /opt/df

#echo "172.31.36.138:/home /home nfs hard,_netdev,noatime 0 2" >> /etc/fstab
echo "172.31.36.138:/opt/slurm /opt/slurm nfs hard,_netdev,noatime 0 2" >> /etc/fstab
mount -a

# note: not all volumes mount at boot. A mount -a command post reboot solves the problem.
# add on crontab as temporary fix this line:
line = "@reboot sleep 30 && mount -a"
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -

cat <<EOF > /etc/profile.d/login-node.sh
export SLURM_HOME='/opt/slurm'
export PATH=\$SLURM_HOME/bin:\$PATH
EOF

cat <<EOF > /etc/systemd/system/slurmd.service
[Unit]
Description=Slurm node daemon
After=munge.service network.target remote-fs.target
ConditionPathExists=/opt/slurm/etc/slurm.conf

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart=/opt/slurm/sbin/slurmd -D $SLURMD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
LimitNOFILE=131072
LimitMEMLOCK=infinity
LimitSTACK=infinity
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable slurmd.service
systemctl start slurmd.service

# now logoff and make a new AMI from this node image
# use the new AMI to spin up multiple login nodes
# can also deregister the initial headnode AMI to save on expenses
# do not forget to manually tag the new login nodes with relevant tags 

# block .cache folders on home. run on the headnode at the end
#find /home -type d -name ".cache" | xargs -l chown root:root
#find /home -type d -name ".cache" | xargs -l chmod 700

# try to mount fsx at /home
# this works in conjunction with compute nodes post install script
# the below script needs to be run at headnode
mkdir -p /temphome
cp -R /home/* /temphome/
echo "fs-0b6e54db851b7b814.fsx.us-east-1.amazonaws.com@tcp:/xznwbbev /home lustre defaults,_netdev,flock,user_xattr,noatime,noauto,x-systemd.automount 0 0" >> /etc/fstab
mount -a
cp -R /temphome/* /home/


### add this code to the compute nodes in the post-install script
awk '/hvtqvbev/{t[1]=$0;next}/bozqnbev/{t[2]=$0;next}{print $0};END {print t[1]}{print t[2]}' fstab


#delete the NFS mount at /home
sed -i '/\/home/d' /etc/fstab
umount /home
echo "fs-0b6e54db851b7b814.fsx.us-east-1.amazonaws.com@tcp:/xznwbbev /home lustre defaults,_netdev,flock,user_xattr,noatime,noauto,x-systemd.automount 0 0" >> /etc/fstab
mount -a

# add rules to motd
cat << REALEND > /etc/update-motd.d/90-HPCrules
#!/bin/sh
cat << EOF
 _   _ ____   ____   ____        _
| | | |  _ \ / ___| |  _ \ _   _| | ___  ___
| |_| | |_) | |     | |_) | | | | |/ _ \/ __|
|  _  |  __/| |___  |  _ <| |_| | |  __/\__ \\
|_| |_|_|    \____| |_| \_\\__,_|_|\___||___/

1. never use the /home dir to store the venv, or any data
2. use anothe folder on /fsx instead of the default ~/.cache with various libs such as HF ones
3. if you need to transfer data, do so from a compute node such as this
srun --partition=login --nodes=1 --ntasks-per-node=1 --cpus-per-task=2 --pty bash -i

Failing no2 will lead us to block access to ~/.cache and scripts will fail
EOF
REALEND

chmod +x /etc/update-motd.d/90-HPCrules
