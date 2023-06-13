#!/bin/bash
set -x
set -e

installCustom() {
    apt-get -y update && apt-get -y upgrade
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt-get -q -o DPkg::Lock::Timeout=240 update
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y build-essential wget htop hwloc iftop aria2 numactl check subunit inotify-tools dotnet-sdk-7.0 bwm-ng subunit rustc cargo 
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y autoconf automake gdb git git-lfs libffi-dev zlib1g-dev ipset libsqlite3-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y libssl-dev python3.8-venv libsndfile1 libsndfile1-dev ffmpeg libx264-dev libx265-dev logrotate
    sudo apt-get -y remove apport
    pip install --upgrade pip
    sudo apt-get -q -oDPkg::Lock::Timeout=240 remove -y postgres*
    #installing python versions
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-venv python3.10-venv python3.11-venv python3.12-venv python3.9-dev python3.10-dev python3.11-dev python3.12-dev iotop iftop bwm-ng
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y python3.9-distutils python3.10-distutils python3.11-distutils
    pip3 install glances
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"
