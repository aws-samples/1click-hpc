The trick to use mpi jobs with apps inside the container is to match the versions of the openmpi from the host with the one from the container

mpigputest.def file will allow to build an image starting with the preffered docker image and adding the correct version of the openmpi (it it does not exists already in which case just env variables should be set only)

`sudo singularity build mpigputest.sif mpigputest.def`

once the image is ready nccl tests can be launched. please note the initial image is compatible with the cluster setup (from AWS Registry)

`sbatch nccl-tests-sif.sh`