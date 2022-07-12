#!/bin/bash
set -e

# Override run_instance attributes
# this example shows how to select the slurm partition and instance type for the capacity reservation. Replace compute-od-2 and m5n-24xlarge with your values
cat > /opt/slurm/etc/pcluster/run_instances_overrides.json << EOF
{
    "compute-od-2": {
        "m5n-24xlarge": {
            "CapacityReservationSpecification": {
                "CapacityReservationTarget": {
                    "CapacityReservationResourceGroupArn": "arn:aws:resource-groups:${AWS_REGION_NAME}:${AWS_ACCOUNT}:group/${CLUSTER_NAME}-ODCR-Group"
                }
            }
        }
    }
}
EOF