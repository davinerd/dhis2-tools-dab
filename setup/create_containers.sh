#!/usr/bin/env bash

# Include useful functions
source libs.sh

# Parse json config file
source parse_config.sh

# ufw status
UFW_STATUS=$(sudo ufw status |grep Status|cut -d ' ' -f 2)

if [[ $UFW_STATUS == "inactive" ]]; then
	echo
	echo "======= ERROR =========================================="
	echo "ufw firewall needs to be enabled in order to perform the installation."
	echo "It is required to NAT connections to the proxy container."
	echo "You just need to have a rule to allow ssh access. eg:"
	echo "   sudo ufw limit 22/tcp"
	echo "then, 'sudo ufw enable'"
	echo "Then you can try to run ./create_containers again"
	exit 1
fi

case $MONITORING in
  munin)
      # echo "Using munin monitor"
      ;;
  *)
      echo "Monitoring tool '$MONITORING' not supported yet"
      exit 1
      ;;
esac

case $APM in
  glowroot)
      # echo "Using glowroot monitor"
      ;;
  *)
      echo "APM '$APM' not supported yet"
      exit 1
      ;;
esac

# Make sure ufw is not blocking the lxd traffic
sudo ufw allow in on $LXDBR
sudo ufw allow out on $LXDBR

sudo apt-get -y install unzip auditd jq apache2-utils

# set any environment variables for default profile in all containers
# example TZ (timezone)
for VAR in $ENVVARS; do
  KEY=$(echo $VAR | jq -r .key)
  VALUE=$(echo $VAR | jq -r .value)
  lxc profile set default environment.$KEY $VALUE
done

# Create and configure containers
for CONTAINER in $CONTAINERS; do
  NAME=$(echo $CONTAINER | jq -r .name)
  IP=$(echo $CONTAINER | jq -r .ip)
  TYPE=$(echo $CONTAINER | jq -r .type)
  OS_VERSION=$(echo $CONTAINER | jq --arg os_version $GUESTOS_VERSION -r '.guestos_version // $os_version')
  REMOTE_HOST=$(echo $CONTAINER | jq -r '.remote_host // empty')

  if [ ! -f "containers/$TYPE" ]; then
	  log_error "Profile for $TYPE doesn't exist .. exiting"
	  exit 1
  fi

  container_exist=$(lxc list -c n | grep -w $NAME)
  if ! [ -z "$container_exist" ]; then
    log_warn "Container $NAME already exist, skipping"
    continue
  fi

  log_info "Creating $NAME of type $TYPE ($GUESTOS $OS_VERSION)"
  if [ "$REMOTE_HOST" ]; then
    remote_host_exist=$(lxc cluster list | grep -w "$REMOTE_HOST")
    if [ -z "$remote_host_exist" ]; then
      log_warn "Remote host '$REMOTE_HOST' not found. Skipping..."
      continue
    else
      lxc init $GUESTOS:$OS_VERSION $NAME --target $REMOTE_HOST
    fi
  else
    lxc init $GUESTOS:$OS_VERSION $NAME
  fi

  lxc network attach $LXDBR $NAME eth0 eth0
  lxc config device set $NAME eth0 ipv4.address $IP

  # create nat rules for proxy
  if [[  $TYPE =~ .*_proxy ]] && [[ $(sudo grep '^\*nat' /etc/ufw/before.rules) != "*nat" ]]; then 
    tmp=$(mktemp)
    sudo cat configs/ufw_proxy /etc/ufw/before.rules > $tmp
    sed -i "s/PROXY_IP/${IP}/g" $tmp

    NETREGEX=$(echo $NETWORK | sed 's/\//\\\//g')
    sed -i "s/LXD_NETWORK/$NETREGEX/g" $tmp
    sed -i "s/INTERFACE/$DEFAULT_INTERFACE/" $tmp

    sudo mv $tmp /etc/ufw/before.rules
    sudo chown root.root /etc/ufw/before.rules
    sudo ufw reload
  fi

  lxc start $NAME
  # wait for network to come up
  while true ; do
    lxc exec $NAME -- nslookup archive.ubuntu.com >/dev/null && break || echo waiting for network; sleep 1 ;
  done

  # run setup scripts
  log_info "Running setup from containers/$TYPE"
  cat containers/$TYPE | lxc exec $NAME -- bash

  if [[ $MONITORING == munin ]] && [[ $TYPE != munin_monitor ]]; then
	lxc exec $NAME -- apt-get install -y munin-node
  lxc exec $NAME -- sed -i -e "\$acidr_allow $MUNIN_IP/32\n" /etc/munin/munin-node.conf
	lxc exec $NAME -- ufw allow proto tcp from $MUNIN_IP to any port 4949
	lxc exec $NAME -- service munin-node restart
  fi

  # source any post setup scripts
  if [[ -f containers/${TYPE}_postsetup ]]; then
    source containers/${TYPE}_postsetup
  fi
done

# If munin then tell the monitor about all the agents
if [[ $MONITORING == munin ]]; then
  #monitor_container_name=$(jq '.containers[] | select(.type | contains("monitor")) |.name' /usr/local/etc/dhis/containers.json | tr -d '"')
  monitor_container_name=$(echo $CONTAINERS | jq '. | select(.type | contains("monitor")) |.name' | tr -d '"')
  log_info "Adding containers to monitor..."
  for CONTAINER in $CONTAINERS; do
    NAME=$(echo $CONTAINER | jq -r .name)
    IP=$(echo $CONTAINER | jq -r .ip)
    TYPE=$(echo $CONTAINER | jq -r .type)

    if [[ $TYPE != munin_monitor ]]; then
      # avoid adding two times the same container
      monitored=$(lxc exec $monitor_container_name -- grep "$NAME" /etc/munin/munin.conf)
      if  [ -z "$monitored" ]; then
        log_info "Adding $NAME to monitor"
        lxc exec $monitor_container_name -- sed -i -e "\$a[$NAME.lxd]\n  address $IP\n  use_node_name yes\n" /etc/munin/munin.conf
      else
        log_warn "Container $NAME already added to monitor. Skipping"
      fi
    fi
  done

  # Also monitor the host
  sudo apt-get install munin-node -y
  if ! [ "$(grep "$MUNIN_IP" /etc/munin/munin-node.conf)" ]; then
    sudo echo "cidr_allow $MUNIN_IP/32" >> /etc/munin/munin-node.conf
    sudo ufw allow proto tcp from $MUNIN_IP to any port 4949
  fi
  sudo service munin-node restart

  lxc exec $monitor_container_name -- /etc/init.d/munin restart
  lxc exec $monitor_container_name -- service apache2 reload
fi
