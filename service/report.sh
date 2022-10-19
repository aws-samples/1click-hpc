#!/bin/bash
sudo /usr/bin/nvidia-bug-report.sh
instance=$(curl http://169.254.169.254/latest/meta-data/instance-id)
echo $instance > instance.txt
echo "$(date --utc +%F\ %T\ %Z)" >> instance.txt
tar -czf $instance.tar.gz instance.txt nvidia-bug-report.log.gz
aws s3 cp $instance.tar.gz s3://stability-aws/
# presign url for case
url=$(aws s3 presign s3://stability-aws/$instance.tar.gz)
# open support case
caseid=$(aws support create-case \
    --category-code "instance-issue" \
    --cc-email-addresses "devops@stability.ai" \
    --communication-body "Our automated scripts detected and isolated an instance that presents degraded GPU performance. Please refer to the debug report available at $url" \
    --issue-type "technical" \
    --language "en" \
    --service-code "amazon-elastic-compute-cloud-linux" \
    --severity-code "high" \
    --subject "Node detected with underperforming GPU" | jq -r '.caseID')
echo "Support case open under id $caseid" >> /fsx/shared/debug.log
# capture the node
sleep 3000000

# place this file in /opt/slurm/sbin