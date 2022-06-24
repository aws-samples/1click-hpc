#!/bin/bash
set -e

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/metrics_amazon_cloudwatch_agent.json << EOF
{
     "agent": {
         "run_as_user": "root"
     },
     "metrics": {
         "namespace": "HPC/GpuMonitoring",
         "append_dimensions": {
             "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
             "ImageId": "${aws:ImageId}",
             "InstanceId": "${aws:InstanceId}",
             "InstanceType": "${aws:InstanceType}" 
         },
         "aggregation_dimensions": [["InstanceId"]],
         "metrics_collected": {
            "nvidia_gpu": {
                "measurement": [
                    "utilization_gpu",
                    "utilization_memory",
                    "temperature_gpu",
                    "power_draw",
                    "memory_total",
                    "memory_used",
                    "memory_free",
                    "clocks_current_memory"
                ]
            }
         }
     }
 }
EOF
