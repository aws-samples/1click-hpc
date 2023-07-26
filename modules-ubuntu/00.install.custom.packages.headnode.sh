#!/bin/bash
set -x
set -e

installCustom() {
    apt-get -y update
    apt-get upgrade -o Dpkg::Options::="--force-confold" -y openssh-server
    apt-get -y upgrade

    #apt-get purge -y ec2-instance-connect #required on ubuntu2004 https://github.com/widdix/aws-ec2-ssh/issues/157
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y build-essential wget tmux htop hwloc iftop aria2 numactl check subunit inotify-tools bwm-ng subunit rustc cargo netcat
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y autoconf automake gdb git git-lfs libffi-dev zlib1g-dev ipset libsqlite3-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y libssl-dev python3.8-venv libsndfile1 libsndfile1-dev ffmpeg libx264-dev libx265-dev logrotate openjdk-11-jre-headless openjdk-8-jre-headless openjdk-17-jre-headless
    sudo apt-get -y remove apport
    pip install --upgrade pip
    sudo apt-get -q -oDPkg::Lock::Timeout=240 remove -y postgres*
    #installing python versions
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt-get -q -o DPkg::Lock::Timeout=240 update
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-venv python3.10-venv python3.11-venv python3.12-venv python3.9-dev python3.10-dev python3.11-dev python3.12-dev iotop iftop bwm-ng
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-distutils python3.10-distutils python3.11-distutils
    pip3 install glances
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.headnode.sh: STOP" >&2
}

main "$@"