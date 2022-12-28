# Parse the contents of containers.json into bash variables
CONFIG=$(cat /usr/local/etc/dhis/containers.json)

# Abort script on errors
#set -o errexit
# test for a valid json config
TESTCONFIG=$(echo $CONFIG |jq .) || { echo "Invalid containers.json"; exit 1; }

FQDN=$(echo $CONFIG | jq -r .fqdn)
EMAIL=$(echo $CONFIG | jq -r .email)
NETWORK=$(echo $CONFIG | jq -r .network)
MONITORING=$(echo $CONFIG | jq -r .monitoring)
APM=$(echo $CONFIG | jq -r .apm)
PROXY=$(echo $CONFIG | jq -r .proxy)
PROXY_IP=$(echo $CONFIG | jq -r '.containers[] | select(.name=="proxy") | .ip')
MUNIN_IP=$(echo $CONFIG | jq -r '.containers[] | select(.name=="monitor") | .ip')
ENCDEVICE=$(echo $CONFIG | jq -r .encrypted_device)
ENVIRONMENT=$(echo $CONFIG | jq ".environment")

CREDENTIALS_FILE="/usr/local/etc/dhis/.credentials.json"

if [[ ! $ENVIRONMENT == "null" ]]; then
  ENVVARS=$(echo $ENVIRONMENT | jq -c "to_entries[]")
fi

# LXD config
LXDBR="lxdbr0"
DEFAULT_INTERFACE=$(ip route |grep default | awk '{print $5}')
#LXDBRADDR=$(lxc network get $LXDBR ipv4.address)

# ubuntu version for containers
GUESTOS="ubuntu"
GUESTOS_VERSION="$(echo $CONFIG | jq -r '.guestos_version // 20.04')"

# ufw status
UFW_STATUS=$(sudo ufw status |grep Status|cut -d ' ' -f 2)

# get configs for individual containers
CONTAINERS=$(echo $CONFIG | jq -c .containers[])
NAMES=$(echo $CONFIG | jq -r .containers[].name)
TYPES=$(echo $CONFIG | jq -r .containers[].type)

case $MONITORING in
     munin)
          # echo "Using munin monitor"
          ;;
     *)
          echo "$MONITORING not supported yet"
          ;;
esac

case $APM in
     glowroot)
          # echo "Using glowroot monitor"
          ;;
     *)
          echo "$APM not supported yet"
          ;;
esac
