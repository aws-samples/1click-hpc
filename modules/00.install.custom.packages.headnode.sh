#!/bin/bash
set -e

amazon-linux-extras enable python3.8
yum install -y python38 python38-devel tmux htop glances aria2 transmission-cli pssh

# optimize for large jobs
ifconfig eth0 txqueuelen 4096
sed -i -e '/MessageTimeout=/ s/=.*/=180/' /opt/slurm/etc/slurm.conf
