#!/usr/bin/env bash

source parse_config.sh

source libs.sh

echo "Are you really sure you want to delete all containers"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

#Remove all credentials
remove_creds "_all_"

for c in $(lxc list --format csv -c n); do 
	echo "Deleting $c"
	lxc delete --force $c
done
