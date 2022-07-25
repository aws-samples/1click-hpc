#!/bin/bash
set -e 

installENROOT{
sysctl -w kernel.unprivileged_userns_clone=1

DIST=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$DIST/libnvidia-container.repo | \
  sudo tee /etc/yum.repos.d/libnvidia-container.repo

yum install -y jq squashfs-tools parallel fuse-overlayfs libnvidia-container-tools pigz squashfuse slurm-devel
export arch=$(uname -m) && sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.0/enroot-3.4.0-2.el7.${arch}.rpm
export arch=$(uname -m) && sudo -E yum install -y https://github.com/NVIDIA/enroot/releases/download/v3.4.0/enroot+caps-3.4.0-2.el7.${arch}.rpm
sudo mkdir /scratch && sudo chmod -R 777 /scratch
git clone https://github.com/NVIDIA/pyxis.git /tmp/pyxis
cd /tmp/pyxis && sudo make rpm && sudo rpm -ihv *.rpm

echo "include /opt/slurm/etc/plugstack.conf.d/*" > /opt/slurm/etc/plugstack.conf
mkdir /opt/slurm/etc/plugstack.conf.d
ln -s /usr/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf

rm /etc/enroot/enroot.conf
cat > /etc/enroot/enroot.conf << EOF
#ENROOT_LIBRARY_PATH        /usr/lib/enroot
#ENROOT_SYSCONF_PATH        /etc/enroot
ENROOT_RUNTIME_PATH        /run/enroot/user-\$(id -u)
ENROOT_CONFIG_PATH         ${HOME}/enroot
ENROOT_CACHE_PATH          /tmp/group-\$(id -g)
ENROOT_DATA_PATH           /tmp/enroot-data/user-\$(id -u)
#ENROOT_TEMP_PATH           ${TMPDIR:-/tmp}

# Gzip program used to uncompress digest layers.
#ENROOT_GZIP_PROGRAM        gzip

# Options passed to zstd to compress digest layers.
#ENROOT_ZSTD_OPTIONS        -1

# Options passed to mksquashfs to produce container images.
#ENROOT_SQUASH_OPTIONS      -comp lzo -noD

# Make the container root filesystem writable by default.
ENROOT_ROOTFS_WRITABLE     yes

# Remap the current user to root inside containers by default.
#ENROOT_REMAP_ROOT          no

# Maximum number of processors to use for parallel tasks (0 means unlimited).
#ENROOT_MAX_PROCESSORS      $(nproc)

# Maximum number of concurrent connections (0 means unlimited).
#ENROOT_MAX_CONNECTIONS     10

# Maximum time in seconds to wait for connections establishment (0 means unlimited).
#ENROOT_CONNECT_TIMEOUT     30

# Maximum time in seconds to wait for network operations to complete (0 means unlimited).
#ENROOT_TRANSFER_TIMEOUT    0

# Number of times network operations should be retried.
#ENROOT_TRANSFER_RETRIES    0

# Use a login shell to run the container initialization.
#ENROOT_LOGIN_SHELL         yes

# Allow root to retain his superuser privileges inside containers.
#ENROOT_ALLOW_SUPERUSER     no

# Use HTTP for outgoing requests instead of HTTPS (UNSECURE!).
#ENROOT_ALLOW_HTTP          no

# Include user-specific configuration inside bundles by default.
#ENROOT_BUNDLE_ALL          no

# Generate an embedded checksum inside bundles by default.
#ENROOT_BUNDLE_CHECKSUM     no

# Mount the current user's home directory by default.
#ENROOT_MOUNT_HOME          no

# Restrict /dev inside the container to a minimal set of devices.
ENROOT_RESTRICT_DEV        no

# Always use --force on command invocations.
#ENROOT_FORCE_OVERRIDE      no

# SSL certificates settings:
#SSL_CERT_DIR
#SSL_CERT_FILE

# Proxy settings:
#all_proxy
#no_proxy
#http_proxy
#https_proxy
EOF

systemctl restart slurm*
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.enroot.pyxis.sh: START" >&2
    installENROOT
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 70.install.enroot.pyxis.sh: STOP" >&2
}

main "$@"