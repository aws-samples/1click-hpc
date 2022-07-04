#!/bin/bash
set -e

amazon-linux-extras enable python3.8
yum install wget tmux python38 glances htop hwloc iftop kernel-tools numactl python3-devel python38-devel kernel-devel check check-devel subunit subunit-devel -y
yum groupinstall -y 'Development Tools'