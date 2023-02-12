#!/usr/bin/env bash
#set -e

source libs.sh

if [ $UID -ne 0 ]; then
    log_error "You must run this script as root. Quitting"
    exit 1
fi

NETREGEX=$(echo $NETWORK | sed 's/\//\\\//g')
PRESEED_FILE="configs/lxd_preseed"

log_info "Updating local machine"
apt-get -y update
apt-get -y upgrade

log_info "Installing/Updating lxd to $LXD_VERSION"
lxd_installed=$(snap list | grep -w lxd)
if [ "$lxd_installed" ]; then
    snap refresh lxd --channel=$LXD_VERSION
else
    snap install lxd --channel=$LXD_VERSION
fi

# initializing lxd system
if [ $CLUSTER_ENABLED = true ]; then
    log_info "Enabling lxd cluster mode"
    PRESEED_FILE="configs/lxd_preseed_cluster"
    local_ifaces=$(ip -br l | awk '$1 !~ "lo" && $2 == "UP" { print $1}')

    echo "Which interface you want the cluster to listen to?"
    ifaces=($local_ifaces)
    select yn in ${ifaces[@]}; do
        LOCAL_IP=$(ip address show $yn | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
        log_info "Using $yn - $LOCAL_IP"
        ufw allow in on $yn to any port 8443
        break
    done
fi

tmp_preseed=$(mktemp)

cat $PRESEED_FILE > $tmp_preseed

sed -i -e "s/HOSTNAME/$(hostname)/" $tmp_preseed
sed -i -e "s/LOCAL_IP/$LOCAL_IP/" $tmp_preseed
sed -i -e "s/NETWORK/${NETREGEX}/" $tmp_preseed

log_info "Initializing lxd"
cat $tmp_preseed | sudo lxd init --preseed

rm -rf $tmp_preseed

# kernel tweaks
cat configs/sysctl >> /etc/sysctl.conf

ufw allow in on $LXDBR
ufw allow out on $LXDBR

ufw route allow in on $LXDBR
ufw route allow out on $LXDBR

source install_scripts.sh

# Create the containers
source create_containers.sh
