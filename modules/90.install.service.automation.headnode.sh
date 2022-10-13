#!/bin/bash
set -x
set -e

installItems(){
    # install some python libs
    python3.8 -m pip install mysql-connector-python

    #install files
    aws s3 cp --quiet "${post_install_base}/sacct/service/report.sh" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/debug.sbatch" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/get_excluded.py" /opt/slurm/sbin/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/sbatch.sh" /tmp/ --region "${cfn_region}" || exit 1
    aws s3 cp --quiet "${post_install_base}/service/prolog_snippet.sh" /tmp/ --region "${cfn_region}" || exit 1

    cp /opt/slurm/bin/sbatch /opt/slurm/bin/sbatch.bak
    mv -f /tmp/sbatch.sh /opt/slurm/bin/sbatch
    chmod +x /opt/slurm/bin/sbatch
    cat /tmp/prolog_snippet.sh >> /opt/slurm/sbin/prolog.sh
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.headnode.sh: START" >&2
    installItems
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 90.install.service.automation.headnode.sh: STOP" >&2
}

main "$@"