#!/bin/bash
# make a hostfile with all the compute nodes that are running

pssh -h hostfile -i "sudo cp /fsx/shared/metrics_amazon_cloudwatch_agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/met$

pssh -h hostfile -i "sudo systemctl restart amazon-cloudwatch-agent"