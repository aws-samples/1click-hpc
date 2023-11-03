#!/bin/bash

set -x
set -e

#usage: on the headnode run the following command where the public key is pasted without quotes (2 or 3 arguments)
#sudo /admin/config/makeuser.sh <username> <publickey>

function addmakeuser() {
    mkdir -p /admin/config
    cat > /admin/config/makeuser <<EOF
#!/bin/bash
sudo useradd -s /bin/bash \$1
sudo mkdir -p /home/\$1/.ssh
sudo chown -R \$1:\$1 /home/\$1
sudo su -l \$1 -c '
  cd ~
  ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
  cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
  echo "\$1 \$2 \$3" | tee -a ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/*
' "\$@"

echo "\$1,$(id -u \$1)" | sudo tee -a /admin/userlistfile
EOF

    chmod +x /admin/config/makeuser
}

# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.manual.users.headnode.sh: START" >&2
    addmakeuser
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 02.manual.users.headnode.sh: STOP" >&2
}

main "$@"
