#!/bin/bash
set -x
set -e

installCustom() {
    wget https://secure.nic.cz/files/knot-resolver/knot-resolver-release.deb
    sudo dpkg -i knot-resolver-release.deb
    sudo apt update
    sudo apt install -y knot-resolver knot-dnsutils knot-resolver-module-http
    TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    mac=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/mac)
    cidrblock=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}/vpc-ipv4-cidr-block)
    read A B C D <<<"${cidrblock//./ }"
    read E F <<< "${D//// }"
    G=$((${E}+2))
    vpcdns="${A}.${B}.${C}.${G}"
    
    echo "supersede domain-name-servers 127.0.0.53, ${vpcdns};" | sudo tee -a /etc/dhcp/dhclient.conf
    echo "net.listen(net.lo, 8053, { kind = 'webmgmt' })" | sudo tee -a /etc/knot-resolver/kresd.conf
    echo "internalDomains = policy.todnames({'ec2.internal','us-east-1.amazonaws.com'})" | sudo tee -a /etc/knot-resolver/kresd.conf
    echo "policy.add(policy.suffix(policy.FLAGS({'NO_CACHE'}), internalDomains))" | sudo tee -a /etc/knot-resolver/kresd.conf
    echo "policy.add(policy.suffix(policy.STUB({'${vpcdns}'}), internalDomains))" | sudo tee -a /etc/knot-resolver/kresd.conf
    sudo sed -i "s/^modules = {/modules = {\n\t'http',/g" /etc/knot-resolver/kresd.conf
    sudo sed -i "s/127.0.0.1/127.0.0.53/g" /etc/knot-resolver/kresd.conf

    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved
    sudo systemctl enable --now kresd@{1..4}.service
    sudo dhclient

    sudo cp /admin/hosts/run-at-startup.service /etc/systemd/system/run-at-startup.service
    sudo systemctl daemon-reload
    sudo systemctl enable run-at-startup.service
}


# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: START" >&2
    installCustom
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] 00.install.knot.resolver.cpu.sh: STOP" >&2
}

main "$@"