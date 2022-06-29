#!/bin/bash

cd /opt
sudo git clone https://github.com/NVIDIA/nccl.git
cd nccl
sudo git checkout {{user `nccl_version`}}
sudo make -j src.build CUDA_HOME=/usr/local/cuda NVCC_GENCODE='-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_80,code=sm_80'
echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib\nexport NCCL_PROTO=simple' | sudo tee /etc/profile.d/nccl.sh

cd /opt
git clone https://github.com/aws/aws-ofi-nccl.git -b aws
cd aws-ofi-nccl
export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
./autogen.sh
sudo mkdir -p /opt/aws-ofi-nccl
./configure --prefix=/opt/aws-ofi-nccl --with-mpi=/opt/amazon/openmpi --with-libfabric=/opt/amazon/efa --with-nccl=/opt/nccl/build --with-cuda=/usr/local/cuda
make && sudo make install
echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/aws-ofi-nccl/lib' | sudo tee /etc/profile.d/aws-ofi-nccl.sh

cd /opt
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make MPI=1 MPI_HOME=/opt/amazon/openmpi CUDA_HOME=/usr/local/cuda NCCL_HOME=/opt/nccl/build
