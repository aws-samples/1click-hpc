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

echo "172.31.32.165:/opt/slurm /opt/slurm nfs hard,_netdev,noatime 0 2" >> /etc/fstab
mount -a

# note: not all volumes mount at boot. A mount -a command post reboot solves the problem.
# add on crontab as temporary fix this line:
line="@reboot sleep 30 && mount -a && systemctl restart slurmd"
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

### add this code to the compute nodes in the post-install script
# awk '/hvtqvbev/{t[1]=$0;next}/bozqnbev/{t[2]=$0;next}{print $0};END {print t[1]}{print t[2]}' fstab

