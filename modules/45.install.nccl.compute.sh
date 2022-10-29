#!/bin/bash
set -x
set -e

installNCCL() {
    echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/amazon/openmpi/lib64:/opt/amazon/efa/lib64\nexport PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin' | sudo tee /etc/profile.d/amazon_efa.sh

    # Install NCCL
    cd /opt
    sudo rm -rf /opt/nccl
    sudo git clone https://github.com/NVIDIA/nccl.git /opt/nccl
    cd /opt/nccl
    pwd
    sudo git checkout 'v2.12.12-1'
    sudo make -j40 src.build CUDA_HOME=/usr/local/cuda NVCC_GENCODE='-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_80,code=sm_80'
    #echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib\nexport NCCL_PROTO=simple' | sudo tee /etc/profile.d/nccl.sh

    cd /opt
    sudo rm -rf /opt/nccl-cuda11.4
    sudo git clone https://github.com/NVIDIA/nccl.git /opt/nccl-cuda11.4
    cd /opt/nccl-cuda11.4
    sudo git checkout 'v2.12.12-1'
    sudo make -j40 src.build CUDA_HOME=/usr/local/cuda-11.4 NVCC_GENCODE='-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_80,code=sm_80'
    #echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib\nexport NCCL_PROTO=simple' | sudo tee /etc/profile.d/nccl.sh

    # Install aws-ofi-nccl
    cd /opt
    sudo rm -rf /opt/aws-ofi-nccl
    sudo git clone https://github.com/aws/aws-ofi-nccl.git -b aws /opt/aws-ofi-nccl
    cd /opt/aws-ofi-nccl
    export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
    sudo ./autogen.sh
    sudo mkdir -p /opt/aws-ofi-nccl
    sudo ./configure --prefix=/opt/aws-ofi-nccl --with-mpi=/opt/amazon/openmpi --with-libfabric=/opt/amazon/efa --with-nccl=/opt/nccl/build --with-cuda=/usr/local/cuda
    sudo make -j40 && sudo make -j40 install
    #echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/aws-ofi-nccl/lib' | sudo tee /etc/profile.d/aws-ofi-nccl.sh

    cd /opt
    sudo rm -rf /opt/aws-ofi-nccl-cuda11.4
    sudo git clone https://github.com/aws/aws-ofi-nccl.git -b aws /opt/aws-ofi-nccl-cuda11.4
    cd /opt/aws-ofi-nccl-cuda11.4
    export PATH=$PATH:/opt/amazon/efa/bin:/opt/amazon/openmpi/bin
    sudo ./autogen.sh
    sudo mkdir -p /opt/aws-ofi-nccl-cuda11.4
    sudo ./configure --prefix=/opt/aws-ofi-nccl-cuda11.4 --with-mpi=/opt/amazon/openmpi --with-libfabric=/opt/amazon/efa --with-nccl=/opt/nccl-cuda11.4/build --with-cuda=/usr/local/cuda-11.4
    sudo make -j40 && sudo make -j40 install
    #echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/aws-ofi-nccl/lib' | sudo tee /etc/profile.d/aws-ofi-nccl.sh

    # Install nccl-tests
    cd /opt
    sudo rm -rf /opt/nccl-tests
    sudo git clone https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests
    cd /opt/nccl-tests
    sudo make -j40 MPI=1 MPI_HOME=/opt/amazon/openmpi CUDA_HOME=/usr/local/cuda NCCL_HOME=/opt/nccl/build

    cd /opt
    sudo rm -rf /opt/nccl-tests-cuda11.4
    sudo git clone https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests-cuda11.4
    cd /opt/nccl-tests-cuda11.4
    sudo make -j40 MPI=1 MPI_HOME=/opt/amazon/openmpi CUDA_HOME=/usr/local/cuda-11.4 NCCL_HOME=/opt/nccl-cuda11.4/build
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 45.install.nccl.compute.sh: START" >&2
    installNCCL
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 45.install.nccl.compute.sh: STOP" >&2
}

main "$@"