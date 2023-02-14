# Service scripts guide
This page illustrates the features and operations of the scripts contained in the [service](../setup/service/) directory, alongside some examples on how to use them.

## dhis2-create-instance
This script creates a container suitable to run DHIS2. What it does is:
* create an Ubuntu container
* create an user and the database in the postgres container
* setup basic DHIS2 configuration parameters like database connection and audit settings
* install and configure tomcat
* install and configure glowroot
* configure the proxy to forward requests to tomcat
* configure logger (if present)
* configure SIEM (if present)

By default, the script configures DHIS2 to log audit trails to file via the `AUDIT2FILE` variable, `true` by default. If will setup the audit system accordingly to [the official documentation](https://docs.dhis2.org/en/manage/performing-system-administration/dhis-core-version-239/audit.html#examples). Works only for DHIS2 version 2.35 and above.

Please note that while this setting works on most versions, **it does not work all the time**. In some edge cases, with this setting, audit system is turned off completely, not saving trails in database nor file: **we strongly suggest you to double check with your version the impact of such changes by monitoring the `audit` table or the `logs/` directory for audit trails**.

To verify if the logs are stored in the database, you can use [dhis2-audit-data-extractor](https://github.com/dhis2/dhis2-utils/tree/master/tools/dhis2-audit-data-extractor).

If you want to keep audit trails in the database (not recommended) you can turn the variable `AUDIT2FILE` to `false`.

### Example
Below the usage and an example:
```
$ dhis2-create-instance
Usage: dhis2-create-instance [options] <instance>
  instance: name of the dhis2 instance to create
Options:
  -i <ip>                          IP address of the container (default picks next free IP ending in .10 to .19)
  -p <postgres_container>          Name of postgresql container (default postgres)
  -o <os_version>                  OS version for container (default 20.04)
  -h, --help                       Display this help message
  -n                               Do NOT create database for instance (default true)
  -j <8|11>                        Java version (default 11)
$ dhis2-create-instance test238
[2023-01-04 14:47:26] [INFO] [dhis2-create-instance] Creating database test238 on postgres
ALTER ROLE
CREATE EXTENSION
Rule added
[2023-01-04 14:47:27] [INFO] [dhis2-create-instance] Creating tomcat container test238 (ubuntu 20.04)
Creating test238
[...]
[2023-01-04 14:50:12] [INFO] [dhis2-create-instance] Instance 'test238' created.
$
```

## dhis2-deploy-war
The aforementioned script deploys a DHIS2 war file inside a previously created instance (with `dhis2-create-instance`).

It can deploy a local war file or directly from the official repository via HTTPS.

### Example
Usage:
```
$ dhis2-deploy-war
Usage: dhis2-deploy-war [options] <instance>
  instance: name of the instance to deploy to
Options:
  -l        http/https URL of war file to deploy
  -f        file path to war file to deploy
  -h, --help       Display this help message
```

Deploying via HTTPS:
```
$ dhis2-deploy-war -l https://releases.dhis2.org/2.38/dhis2-stable-2.38.1.war test2381
--2023-01-07 12:11:03--  https://releases.dhis2.org/2.38/dhis2-stable-2.38.1.war
Resolving releases.dhis2.org (releases.dhis2.org)... 18.161.97.111, 18.161.97.122, 18.161.97.75, ...
Connecting to releases.dhis2.org (releases.dhis2.org)|18.161.97.111|:443... connected.
[...]
[2023-01-07 12:15:28] [INFO] [dhis2-deploy-war] Deploying new war file
[2023-01-07 12:15:41] [INFO] [dhis2-deploy-war] test2381 DHIS2 deployment done
```

## dhis2-set-credential
This script sets credentials for supported services. All credentials are stored under `/usr/local/etc/dhis/.credentials.json`, by default only accessible by root.

The credentials file is a JSON with the following schema:
```
{
    "credentials": [
        {
            "service": <name of the service>,
            "username": <username to access the service>,
            "password": <password to access the service>
        }
    ]
}
```

In the [libs.sh](../setup/libs.sh) file there are three functions to manage credentials: `save_creds`, `get_creds` and `remove_creds`. The first one is used within this script, while the others are and can be used in other scripts (by sourcing the `libs.sh` file).

`dhis2-set-credentials` can be used within script and postsetup scripts as well, or manually from shell to change/rotate credentials, even as a part of a cron job.

Please note: when changing DHIS2 admin credentials via the `dhis2-admin` service, **currently active admin sessions are not invalidated**. If you want to invalidate when the password is changed, please set the variable `INVALIDATE_ADMIN_SESSION` to `true` before running the script.

### Example
Usage:
```
$ dhis2-set-credential
Set credential for services.

usage: dhis2-set-credential <SERVICE> <CONTAINER_NAME> [<credentials>]
  Valid services are: munin glowroot elasticsearch dhis2-admin
Options:
credentials   JSON string containing the credentials in form: '{"service":"service name","username":"user","password":"password"}'
              The JSON string must be formatted exactly as shown above (not have spaces around colons and semicolons, proper use of quotes).
```

Changing password for `glowroot` manually:
```
$ sudo dhis2-set-credential glowroot test238
[2023-01-07 00:21:30] [INFO] [dhis2-set-credential] Service glowroot found. Setting credentials
==============================
Do you want to add the password manually for the user admin in the service glowroot? (If not, password will be generated randomly)
1) Yes
2) No
#? 2
[...]
[2023-01-07 00:21:36] [INFO] [dhis2-set-credential] Glowroot credentials set. Restarting tomcat
Credentials have been set:
=========================
Instance: test238
Service: test238-glowroot
Username: admin
Password: cb727b6ba27cad1b061baafdbf5ec3cfb559f6f907540866
$
```

To check the content of the credentials file:
```
$ sudo cat /usr/local/etc/dhis/.credentials.json
{
  "credentials": [
    {
      "service": "munin",
      "username": "admin",
      "password": "638f70dabb638aed8edb0d65"
    },
    {
      "service": "elasticsearch",
      "username": "elastic",
      "password": "LHBjueS9dvemQ*lndRF9"
    },
    {
      "service": "test238-glowroot",
      "username": "admin",
      "password": "cb727b6ba27cad1b061baafdbf5ec3cfb559f6f907540866"
    }
  ]
}
```

To retrieve credentials for a specific service, there are mainly two options. Assuming we want to retrieve credentials for `munin`, here are the options:

Option \#1:
```
$ sudo cat /usr/local/etc/dhis/.credentials.json | jq -r '.credentials[] | select(.service=="munin")'
{
  "service": "munin",
  "username": "admin",
  "password": "638f70dabb638aed8edb0d65"
}
```
Option \#2:
```
$ source libs.sh
$ get_creds "munin"
{ "service": "munin", "username": "admin", "password": "638f70dabb638aed8edb0d65" }
```

To change DHIS2 admin password for a container named `testdev`:
```
$ sudo dhis2-set-credential dhis2-admin testdev
[2023-02-14 14:00:18] [INFO] [dhis2-set-credential] Service dhis2-admin found. Setting credentials
==============================
Do you want to add the password manually for the user admin in the service dhis2-admin? (If not, password will be generated randomly)
1) Yes
2) No
#? 2
{"httpStatus":"OK","httpStatusCode":200,"status":"OK","response":{"responseType":"ImportReport","status":"OK","stats":{"created":0,"updated":1,"deleted":0,"ignored":0,"total":1},"typeReports":[{"klass":"org.hisp.dhis.user.User","stats":{"created":0,"updated":1,"deleted":0,"ignored":0,"total":1},"objectReports":[{"klass":"org.hisp.dhis.user.User","index":0,"uid":"M5zQapPyTZI","errorReports":[]}]}]}}

Credentials have been set:
=========================
Instance: testdev
Service: testdev-dhis2-admin
Username: admin
Password: 6fT8#t{tJ=D<oG*!>8ve7J%x
$
```

## dhis2-set-journal
This script sets services within a container to log via the journal file (thanks to the journald service).

Since every service and system has a different configuration for logging to journal, each time a new one is added to the tool, it must be manually implemented in this script.

Currently, the script supports `DHIS2` (via a custom [log4j2](https://logging.apache.org/log4j/2.x/) configuration file present in the [etc directory of this repository](../setup/etc/log4j2.xml)), `nginx`, `apache`, `postgres`, `munin-node`.

When a centralized logger (a container of type `journal_logger`) is present, the script can be instructed to configure journal logs to be shipped directly to it, as seen in the example section.

### Example
Usage:
```
$ dhis2-set-journal
Usage: dhis2-set-journal [options] <instance> [<type>]
  instance: name of the container to configure
Options:
  -r                 Configure remote shipping (default false)
  -i <remote_ip>     IP address of the remote host to receive logs (mandatory when -r)
  -h, --help         Display this help message
```

Setup journal for a DHIS2 instance and ship the logs to a container with IP `192.168.0.100`:
```
$ dhis2-set-journal -r -i 192.168.0.100 test2381
[2023-01-07 13:50:18] [INFO] [dhis2-set-journal] Copying log4j2.xml for logging to journal...
[2023-01-07 13:50:20] [INFO] [dhis2-set-journal] Configuring remote logs to 192.168.0.100
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following additional packages will be installed:
  libmicrohttpd12
The following NEW packages will be installed:
  libmicrohttpd12 systemd-journal-remote
0 upgraded, 2 newly installed, 0 to remove and 0 not upgraded.
[...]
Adding system user `systemd-journal-upload' (UID 114) ...
Adding new group `systemd-journal-upload' (GID 121) ...
Adding new user `systemd-journal-upload' (UID 114) with group `systemd-journal-upload' ...
Not creating home directory `/run/systemd'.
Created symlink /etc/systemd/system/multi-user.target.wants/systemd-journal-upload.service → /lib/systemd/system/systemd-journal-upload.service.
$
```

To configure a `postgres` container to enable local journal logging (`munin` is detected on the container and configured as well):
```
$ dhis2-set-journal postgres postgres
[2023-01-07 13:51:43] [INFO] [dhis2-set-journal] Configuring postgres to log to journal
[2023-01-07 13:51:44] [INFO] [dhis2-set-journal] Configuring munin node to log to journal
$
```

## dhis2-set-elasticsearch
This script configures any container to send logs to a centralized Elasticsearch instance.

It uses [filebeat](https://www.elastic.co/beats/filebeat) with a [default configuration file](../setup/etc/filebeat.yml), which collects logs from the journal (you may want to use `dhis2-set-journal` before running this script).

### Example
Usage:
```
$ dhis2-set-elasticsearch
Usage: dhis2-set-elasticsearch [-h] -i <elasticsearch ip> <instance>
  instance: name of the container to configure
Options:
  -i <elasticsearch ip>     IP address of Elasticsearch (mandatory)
  -h, --help                Display this help message
```

To manually configure a newly created instance to communicate to an elasticsearch SIEM:
```
$ dhis2-set-elasticsearch -i 192.168.0.200 test2381
[2023-01-07 13:31:12] [INFO] [dhis2-set-elasticsearch] Retrieving filebeat 8.4.1 (arm64)
[2023-01-07 13:31:13] [INFO] [dhis2-set-elasticsearch] Installing filebeat
Selecting previously unselected package filebeat.
(Reading database ... 32942 files and directories currently installed.)
Preparing to unpack /tmp/filebeat.deb ...
Unpacking filebeat (8.4.1) ...
Setting up filebeat (8.4.1) ...
Processing triggers for systemd (245.4-4ubuntu3.19) ...
[2023-01-07 13:31:15] [INFO] [dhis2-set-elasticsearch] Configuring filebeat
Synchronizing state of filebeat.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable filebeat
Created symlink /etc/systemd/system/multi-user.target.wants/filebeat.service → /lib/systemd/system/filebeat.service.
[2023-01-07 13:31:16] [INFO] [dhis2-set-elasticsearch] Filebeat configured. All good
$
```
