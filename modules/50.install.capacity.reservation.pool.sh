#!/bin/bash
set -e

# Override run_instance attributes
cat > /opt/slurm/etc/pcluster/run_instances_overrides.json << EOF
{
    "compute-od-1": {
        "p4d-24xlarge": {
            "CapacityReservationSpecification": {
                "CapacityReservationTarget": {
                    "CapacityReservationResourceGroupArn": "arn:aws:resource-groups:us-east-1:842865360552:group/EC2CRGroup"
                }
            }
        }
    }
}
EOF