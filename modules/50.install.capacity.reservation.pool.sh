#!/bin/bash
set -e

# Override run_instance attributes
# Name of the group is still hardcoded, need a way to get variable from cloudformation here
cat > /opt/slurm/etc/pcluster/run_instances_overrides.json << EOF
{
    "compute-od-gpu": {
        "p4d-24xlarge": {
            "CapacityReservationSpecification": {
                "CapacityReservationTarget": {
                    "CapacityReservationResourceGroupArn": "arn:aws:resource-groups:${AWS_REGION_NAME}:${AWS_ACCOUNT}:group/${CLUSTER_NAME}-ODCR-Group"
                }
            }
        }
    },
    "compute-od-mig": {
        "p4d-24xlarge": {
            "CapacityReservationSpecification": {
                "CapacityReservationTarget": {
                    "CapacityReservationResourceGroupArn": "arn:aws:resource-groups:${AWS_REGION_NAME}:${AWS_ACCOUNT}:group/${CLUSTER_NAME}-ODCR-Group"
                }
            }
        }
    }
}
EOF