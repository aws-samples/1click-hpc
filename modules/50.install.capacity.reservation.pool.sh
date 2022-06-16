#!/bin/bash
set -e

ACCOUNT_ID=`aws sts get-caller-identity | jq -r '."Account"'`
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

# Override run_instance attributes
# Name of the group is still hardcoded, need a way to get variable from cloudformation here
cat > /opt/slurm/etc/pcluster/run_instances_overrides.json << EOF
{
    "compute-od-gpu": {
        "p4d-24xlarge": {
            "CapacityReservationSpecification": {
                "CapacityReservationTarget": {
                    "CapacityReservationResourceGroupArn": "arn:aws:resource-groups:$EC2_REGION:$ACCOUNT_ID:group/EC2CRGroup"
                }
            }
        }
    }
}
EOF