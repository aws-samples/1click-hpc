#!/bin/bash
set -x
set -e

installItems(){
    # install some python libs
    python3.8 -m pip install mysql-connector-python botocore aws_secretsmanager_caching

    #install files
    aws s3 cp --quiet "${post_install_base}/service/report.sh" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/debug.sbatch" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/get_excluded.py" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/sbatch.sh" /tmp/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/prolog.sh" /tmp/ --region "${cfn_region}" || exit 1

    mv /opt/slurm/bin/sbatch /opt/slurm/bin/sbatch.bak
    mv /tmp/sbatch.sh /opt/slurm/bin/sbatch
    mv -f /tmp/prolog.sh /opt/slurm/sbin/prolog.sh
    chmod +x /opt/slurm/bin/sbatch
    chmod +x /opt/slurm/sbin/report.sh
    chmod +x /opt/slurm/sbin/prolog.sh 
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.headnode.sh: START" >&2
    installItems
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.headnode.sh: STOP" >&2
}

main "$@"