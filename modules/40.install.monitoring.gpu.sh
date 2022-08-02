#!/bin/bash
set -x
set -e

installEFAmon() {
    # Install EFA Exporter
    /usr/bin/python3 -m pip install --upgrade pip
    pip3 install boto3
    yum install amazon-cloudwatch-agent -y
    git clone https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline.git /tmp/aws-efa-nccl-baseami
    mv /tmp/aws-efa-nccl-baseami/nvidia-efa-ami_base/cloudwatch /opt/aws/
    mv /opt/aws/cloudwatch/aws-hw-monitor.service /lib/systemd/system
    echo -e "#!/bin/sh\n" | tee /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
    echo -e "/usr/bin/python3 /opt/aws/cloudwatch/nvidia/aws-hwaccel-error-parser.py &\n" | tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
    echo -e "/usr/bin/python3 /opt/aws/cloudwatch/nvidia/accel-to-cw.py /opt/aws/cloudwatch/nvidia/nvidia-exporter >> /dev/null 2>&1 &\n" | tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
    echo -e "/usr/bin/python3 /opt/aws/cloudwatch/efa/efa-to-cw.py /opt/aws/cloudwatch/efa/efa-exporter >> /dev/null 2>&1 &\n" | tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
    chmod +x /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
    systemctl enable aws-hw-monitor.service
    systemctl start aws-hw-monitor.service
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.gpu.sh: START" >&2
    installEFAmon
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 40.install.monitoring.gpu.sh: STOP" >&2
}

main "$@"