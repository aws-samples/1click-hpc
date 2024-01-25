#!/bin/bash
set -x
set -e

installCustom() {
    #set precedence for IPv4 over IPv6
    sed -i 's/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/g' /etc/gai.conf

    apt-get -y update 
    UCF_FORCE_CONFFOLD=1 apt-get upgrade -y openssh-server
    apt-get -y upgrade
    #apt-get purge -y ec2-instance-connect #required on ubuntu2004 https://github.com/widdix/aws-ec2-ssh/issues/157
    apt-get -q -o DPkg::Lock::Timeout=240 install -y build-essential wget htop hwloc iftop aria2 numactl check subunit inotify-tools bwm-ng subunit rustc cargo netcat memcached libmemcached-tools
    apt-get -q -o DPkg::Lock::Timeout=240 install -y autoconf automake gdb git git-lfs libffi-dev zlib1g-dev ipset libsqlite3-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev
    apt-get -q -o DPkg::Lock::Timeout=240 install -y libssl-dev python3.8-venv libsndfile1 libsndfile1-dev ffmpeg libx264-dev libx265-dev logrotate openjdk-11-jre-headless openjdk-8-jre-headless openjdk-17-jre-headless
    apt-get -y remove apport thunderbird*
    pip install --upgrade pip
    apt-get -q -oDPkg::Lock::Timeout=240 remove -y postgres*
    
    #installing python versions
    add-apt-repository ppa:deadsnakes/ppa -y
    apt-get -q -o DPkg::Lock::Timeout=240 update
    apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-venv python3.10-venv python3.11-venv python3.12-venv python3.9-dev python3.10-dev python3.11-dev python3.12-dev iotop iftop bwm-ng
    apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-distutils python3.10-distutils python3.11-distutils
    pip3 install glances
    apt-get -y autoremove
    sudo -v ; curl https://rclone.org/install.sh | sudo bash

    if [ -f /admin/config/weka_stateless_client.sh ]; then
        /admin/config/weka_stateless_client.sh
    fi
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"
