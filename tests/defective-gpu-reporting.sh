#!/bin/bash
sudo nvidia-bug-reporting.sh
instance=$(curl http://169.254.169.254/latest/meta-data/instance-id)
echo $instance > instance.txt
echo "$(date --utc +%F\ %T\ %Z)" >> instance.txt
tar -czf $instance.tar.gz instance.txt nvidia-bug-report.log.gz
aws s3 cp $instance.tar.gz s3://stability-aws/
# link expires August 5, 2022
curl -s https://d1mg6achc83nsz.cloudfront.net/343d4e493bfa7d3434d2812d0b9bb617eaa6f79913f3065850adec399b65b04f/us-east-1/instance.tar.gz
