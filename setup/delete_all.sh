#!/usr/bin/env bash

source libs.sh

log_warn "Are you really sure you want to delete all containers"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

for c in $(lxc list --format csv -c n); do 
	log_info "Deleting $c"
	lxc delete --force $c
done

#Remove all credentials
log_info "Removing all credentials"
remove_creds "_all_"