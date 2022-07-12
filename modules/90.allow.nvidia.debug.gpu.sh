#!/bin/bash
set -e

aws s3 cp --quiet "${post_install_base}/nvidia/99-nvidia-debug" /etc/sudoers.d/ --region "${cfn_region}" || exit 1
