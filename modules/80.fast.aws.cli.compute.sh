#!/bin/bash
set -x
set -e

makeAWSCLIfast() {
    aws configure set default.s3.max_concurrent_requests 100
    aws configure set default.s3.max_queue_size 10000
    aws configure set default.s3.multipart_threshold 64MB
    aws configure set default.s3.multipart_chunksize 16MB
    aws configure set default.s3.tcp_keepalive true
}

makeLUSTREfast() {
    # as per AWS Support and https://docs.aws.amazon.com/fsx/latest/LustreGuide/performance.html
    lctl set_param ldlm.namespaces.*.lru_max_age=600000
    echo "options ptlrpc ptlrpcd_per_cpt_max=32" >> /etc/modprobe.d/modprobe.conf
    echo "options ksocklnd credits=2560" >> /etc/modprobe.d/modprobe.conf

    line = "@reboot sleep 180 && lctl set_param osc.*OST*.max_rpcs_in_flight=32"
    (crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
    line = "@reboot sleep 185 && lctl set_param mdc.*.max_rpcs_in_flight=64"
    (crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
    line = "@reboot sleep 190 && lctl set_param mdc.*.max_mod_rpcs_in_flight=50"
    (crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 80.fast.aws.cli.compute.sh: START" >&2
    makeAWSCLIfast
    makeLUSTREfast
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 80.fast.aws.cli.compute.sh: STOP" >&2
}

main "$@"