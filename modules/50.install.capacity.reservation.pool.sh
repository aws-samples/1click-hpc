#!/bin/bash
set -e

# Override run_instance attributes
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
    }
}
EOF