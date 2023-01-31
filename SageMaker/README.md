# SageMaker Cluster Post-Install scripts
These are the post-install scripts we use for the SageMaker provided cluster that work on top of the Deep Learning AMI provided by SageMaker team.

The AMI comes with:
1. all NVidia drivers, cuda versions, cudnn versions. We are applying environment modules to make switching easy
1. lustre driver preinstalled
1. pytorch and various python libs preinstalled

In addition we add:
1. slurm compilation on every node (the headnode is prepared manually beforehand)
1. DCGMI installation as well as DCGMI-Exporter for openmetrics integrations
1. Tuning AWS cli performance
1. Adding some custom packages, including DataDog agent
1. Replacing the default resolver with a more performant one (only needed if mass downloads are to be performed)
1. Using the 8x 1TB available nvme devices to build a very fast RAID0 /scratch volume
1. Installing singularity and enroot/pyxis to be used with containers
1. Installing and configuring SSSD integration with LDAPS endpoint (useful for authorization and authentication)

These scripts or a selection of them should be executed from an S3 bucket by the compute nodes provisioning template.


# License

This software is licensed under the MIT-0 License. See the LICENSE file.
