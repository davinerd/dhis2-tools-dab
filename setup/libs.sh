source parse_config.sh

function log {
  local readonly script_name="$(basename "$0")"
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[${timestamp}] [${level}] [$script_name] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function save_creds {
  local readonly creds=$1
  local tmpfile="$(mktemp)" || exit 1
  local service=$(jq .service <<< $creds | tr -d '"')

  # remove old service creds
  jq --arg srvc $service 'del(.credentials[] | select(.service == $srvc))' $CREDENTIALS_FILE > $tmpfile

  # because of https://github.com/stedolan/jq/issues/105
  echo "$(jq --argjson jstr $creds '.credentials += [$jstr]' $tmpfile)" > $tmpfile

  mv -f $tmpfile $CREDENTIALS_FILE
}

function remove_creds {
  local readonly service=$1

  local tfile=$(mktemp)
  if [[ $service == "_all_" ]]; then
    sudo jq 'del(.credentials[])' ${CREDENTIALS_FILE} > ${tfile}
  else
    sudo jq --arg name $service 'del(.credentials[] | select(.service == $name))' $CREDENTIALS_FILE > ${tfile}
  fi
  sudo mv ${tfile} ${CREDENTIALS_FILE}
}

function get_creds {
  local readonly service=$1
  local creds=$(sudo jq --arg srvc $service '.credentials[] | select(.service == $srvc)' $CREDENTIALS_FILE)
  echo $creds
}