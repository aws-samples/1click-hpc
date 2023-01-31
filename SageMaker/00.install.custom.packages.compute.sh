#!/bin/bash
set -x
set -e

installCustom() {
    sudo apt-get -q -o DPkg::Lock::Timeout=240 update
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y build-essential wget tmux htop hwloc iftop aria2 numactl check subunit
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y autoconf automake gdb git git-lfs libffi-dev zlib1g-dev ipset
    sudo apt-get -q -o DPkg::Lock::Timeout=240 install -y libssl-dev python3.8-venv libsndfile1 libsndfile1-dev ffmpeg
    sudo apt-get -y remove apport
    pip install --upgrade pip
    pip install pynvml glances
    sudo apt-get remove -y postgres*

    mkdir -p /usr/share/modules/modulefiles/cuda/
    aws s3 sync --quiet s3://pcluster-testing/sagemaker-scripts/cuda-modules/ /usr/share/modules/modulefiles/cuda/ --region us-east-1

    cat >/usr/share/modules/modulefiles/cuda/.version <<EOF
#%Module
set ModulesVersion 11.7
EOF
}

installCostControl() {
#prepare cost control scripts
sudo mkdir -p /tmp/jobs
# Configure the script to run every minute
line="* * * * * /admin/hosts/check_tags.sh"
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
}

installDatadog() {
    DD_API_KEY=<useDatadogAPIkeyHere> DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    sudo datadog-agent integration install -t datadog-nvml==1.0.5 -r
    sudo -u dd-agent -H /opt/datadog-agent/embedded/bin/pip3 install grpcio pynvml
    sudo cp /etc/datadog-agent/conf.d/nvml.d/conf.yaml.example /etc/datadog-agent/conf.d/nvml.d/conf.yaml
    sudo mv /etc/datadog-agent/conf.d/btrfs.d/conf.yaml.example /etc/datadog-agent/conf.d/btrfs.d/conf.yaml
    sudo cp /admin/hosts/openmetrics-conf.yaml /etc/datadog-agent/conf.d/openmetrics.d/conf.yaml
    sudo cp /admin/hosts/datadog.yaml /etc/datadog-agent/datadog.yaml
    sudo systemctl restart datadog-agent
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: START" >&2
    installCustom
    installDatadog
    installCostControl
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.custom.packages.compute.sh: STOP" >&2
}

main "$@"
