#!/bin/bash
set -e

makeAWSCLIfast{
    aws configure set default.s3.max_concurrent_requests 100
    aws configure set default.s3.max_queue_size 10000
    aws configure set default.s3.multipart_threshold 64MB
    aws configure set default.s3.multipart_chunksize 16MB
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 80.fast.aws.cli.compute.sh: START" >&2
    makeAWSCLIfast
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 80.fast.aws.cli.compute.sh: STOP" >&2
}

main "$@"