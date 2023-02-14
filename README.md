# dhis2-tools-dab

Tools for setting up [DHIS2](https://dhis2.org) on LXD.

This tool combines the work done by [Solidlines](https://github.com/solid-lines/dhis2-tools-ng) and Bob Jolliffe on [dhis2-tools-ng](https://github.com/bobjolliffe/dhis2-tools-ng), extending their features and adding some more.

This version includes, on top of the original tool's features:
- Improved output
- Improved credentials storage and retrieval (consistency and security)
- More robust setup for increased flexibility and customization (reduced hardcoded values)
- Possibility to specify different ubuntu versions for each container (in `containers.json` or via `dhis2-create-instance`)
- LXD cluster support (disabled by default in `parse_config.sh`)
- Upgraded LXD from 4.0 to 5.0
- Compliant with CIS Benchmarks (supported: `tomcat9`). Checked with [dhis2-inspec](https://github.com/davinerd/dhis2-inspec).
- Automatic rotate built-in default admin account password (thanks to [`dhis2-set-credentials`](./docs/service_scripts.md#dhis2-set-credential)).

New container types have been added:
- container type `journal_logger`
  - configure services output to journal (journald)
  - configure DHIS2, tomcat, proxy, database and all containers to log to journal
  - configure all containers to ship logs remotely to the journal logger container
  - ship the logs outside the journal logger container. Supported backends are (for now): host filesystem and S3 providers (aws, gcp, contabo, linode, digitalocean)
- container type `siem_es`
  - setup a SIEM based on Elasticsearch
  - configure all containers to extract logs from journald and send them to elasticsearch via filebeat

For more information on how LXD cluster works, please refer to the [official guide](https://linuxcontainers.org/lxd/docs/master/clustering/). For a DHIS2 specific lxd cluster guide, please refer to [this blog post](https://medium.com/@dabsolutions).

For more detailed information on the container types, please read the [container types document](docs/container_types.md).

For details on the added functionalities to the service scripts, please refer to the [service scripts document](docs/service_scripts.md).

## Install
If this is the first time you are setting up dhis2-tools-dab, very few has changed from the original installation guide.
Feel free to read how to install it and what is required to do so by reading the original document [here](https://github.com/bobjolliffe/dhis2-tools-ng/blob/master/README.md)

## Upgrade
Most of the users have already configured dhis2-tools-ng and most likely want to upgrade to dhis2-tools-dab.

You can do this safely. No downtime should occur. However, we suggest to test it in a testing environment before upgrading production systems.

We also suggest to backup containers in case something goes wrong.

A full upgrade guide has been described [in this blog post](https://medium.com/@dabsolutions).

Here are the steps to perform the upgrade:

1. Download the code
```
$ git clone https://github.com/davinerd/dhis2-tools-dab.git && cd dhis2-tools-dab/setup
```

2. Run LXD setup
```
dab@battlechine:~/dhis2-tools-dab/setup$ sudo ./lxd_setup.sh
```

This will:
- Update LXD from version 4.0 to version 5.0 stable
- Install the new scripts (under `/usr/local/bin`)
- Check for missing containers specified in `/usr/local/etc/dhis/containers.json`

3. Verify everything works as expected
```
dab@battlechine:~/dhis2-tools-dab/setup$ lxc list
+----------+---------+---------------------+------+-----------+-----------+
|   NAME   |  STATE  |        IPV4         | IPV6 |   TYPE    | SNAPSHOTS |
+----------+---------+---------------------+------+-----------+-----------+
| monitor  | RUNNING | 192.168.0.30 (eth0) |      | CONTAINER | 0         |
+----------+---------+---------------------+------+-----------+-----------+
| postgres | RUNNING | 192.168.0.20 (eth0) |      | CONTAINER | 0         |
+----------+---------+---------------------+------+-----------+-----------+
| proxy    | RUNNING | 192.168.0.2 (eth0)  |      | CONTAINER | 0         |
+----------+---------+---------------------+------+-----------+-----------+
```

## Notes
If you wish to use LXD cluster mode, set the `CLUSTER_ENABLED` variable to `true` in [parse_config.sh](./setup/parse_config.sh).

If you wish to stay with LXD version 4.0, set the `LXD_VERSION` variable to `4.0/stable` in [parse_config.sh](./setup/parse_config.sh).

When cluster is enabled and containers don't have a `remote_host` key specified, lxd automatically creates the container on the machine with more resources available.
You will need to specify the `remote_host` key for all containers if you want to force the creation on a specific host.

## Keys Reference
Following are all the generic and global keys available for `containers.json`. For container-specific keys, please refer to the [container types document](docs/container_types.md).

A default value of `N/A` means that it must be assigned before running the scripts. Default values are either in the [containers.json.sample](setup/configs/containers.json.sample) file or in code.

|   KEY    |  VALUES        |    DEFAULT      | MANDATORY | DESCRIPTION            |
|----------|----------------|-----------------|-----------|------------------------|
| fqdn     | Any valid FQDN | `N/A`           |   Y       | FQDN used to access the DHIS2 instances |
| email    | email address  | `N/A`           |   Y       | email address used for SSL/TLS certificates |
| environment.TZ  | Timezone | `Africa/Accra` |   Y  | Timezone to configure on each container |
| network  | CIDR | `192.168.0.1/24` |   Y  | IP range to use within LXD |
| monitoring  | [`munin`] | `munin` |   Y  | Monitoring tool for containers |
| apm  | [`glowroot`] | `glowroot` |   Y  | Application Performance Management tools |
| proxy  | [`nginx`, `apache`] | `nginx` |   Y  | Type of proxies supported by DHIS2 |
| guestos_version  | String | `20.04` |  N  | Any Ubuntu version supported by lxd |
| containers.name  | String | `N/A` |   Y  | Name of the container |
| containers.type  | See [docs](docs/container_types.md) | `N/A` |   Y  | Type of the container. See documentation for details |
| containers.ip  | IP address | `N/A` |   Y  | IP address for the container within the `network` CIDR |
| containers.guestos_version  | String | `guestos_version` |   N | Any Ubuntu version. If not specified, the main `guestos_version` value is used |
| containers.remote_host  | String | `N/A` |   N | The hostname of a member of the cluster |


## Examples
### Different Ubuntu versions
The follow examples show how to `proxy` containers will run Ubuntu 22.04, as specified by the `guestos_version` key. All other containers will run the default Ubuntu version (20.04).

```
{
  "fqdn":"my.custom.fqdn",
  "email": "davide@my.custom.fqdn",
  "environment": {
    "TZ": "Europe/Madrid"
  },
  "network": "192.168.0.1/24",
  "monitoring": "munin",
  "apm": "glowroot",
  "proxy": "nginx",
  "containers": [
    {
      "name": "proxy",
      "ip": "192.168.0.2",
      "type": "nginx_proxy",
      "guestos_version": "22.04"
    },
    {
      "name": "postgres",
      "ip": "192.168.0.20",
      "type": "postgres"
    },
    {
      "name": "monitor",
      "ip": "192.168.0.30",
      "type": "munin_monitor"
    }
  ]
}
```

If you want all systems to run on a version different than `20.04`, you can move the `guestos_version` up to a level, as shown below. With the following example, all containers will run Ubuntu `22.04` by default (you can still specify the `guestos_version` key for each container to set for exceptions).

```
{
  "fqdn":"my.custom.fqdn",
  "email": "davide@my.custom.fqdn",
  "environment": {
    "TZ": "Europe/Madrid"
  },
  "network": "192.168.0.1/24",
  "monitoring": "munin",
  "apm": "glowroot",
  "proxy": "nginx",
  "guestos_version": "22.04",
  "containers": [
    {
      "name": "proxy",
      "ip": "192.168.0.2",
      "type": "nginx_proxy"
    },
    {
      "name": "postgres",
      "ip": "192.168.0.20",
      "type": "postgres"
    },
    {
      "name": "monitor",
      "ip": "192.168.0.30",
      "type": "munin_monitor"
    }
  ]
}
```

To spin up a DHIS2 container with a specific Ubuntu version, you can do so by using the new feature of `dhis2-create-instance`. To read more about it, please refer to the [service scripts documentation](docs/service_scripts.md#dhis2-create-instance).
```
dab@battlechine:~/dhis2-tools-dab/setup$ dhis2-create-instance -o 22.04 testing
[2023-01-06 17:20:13] [INFO] [dhis2-create-instance] Creating database testing on postgres
ALTER ROLE
CREATE EXTENSION
Rule added
[2023-01-06 17:20:14] [INFO] [dhis2-create-instance] Creating tomcat container testing (ubuntu 22.04)
Creating testing
[...]
```

### Remote host 
In the following example, lxd will spin the container `postgres` to a remote host, thanks to the cluster support. The `srv_database` host has been previously configured and added to the main node `battlechine`, and it resides on a different physical machine.

```
{
  "fqdn":"my.custom.fqdn",
  "email": "davide@my.custom.fqdn",
  "environment": {
    "TZ": "Europe/Madrid"
  },
  "network": "192.168.0.1/24",
  "monitoring": "munin",
  "apm": "glowroot",
  "proxy": "nginx",
  "containers": [
    {
      "name": "proxy",
      "ip": "192.168.0.2",
      "type": "nginx_proxy"
    },
    {
      "name": "postgres",
      "ip": "192.168.0.20",
      "type": "postgres".
      "remote_host": "srv_database"
    },
    {
      "name": "monitor",
      "ip": "192.168.0.30",
      "type": "munin_monitor"
    }
  ]
}
```

To verify:
```
dab@battlechine:~/dhis2-tools-dab/setup$ lxc list
+----------+---------+---------------------+------+-----------+-----------+--------------+
|   NAME   |  STATE  |        IPV4         | IPV6 |   TYPE    | SNAPSHOTS |   LOCATION   |
+----------+---------+---------------------+------+-----------+-----------+--------------+
| monitor  | RUNNING | 192.168.0.30 (eth0) |      | CONTAINER | 0         | battlechine  |
+----------+---------+---------------------+------+-----------+-----------+--------------+
| postgres | RUNNING | 192.168.0.20 (eth0) |      | CONTAINER | 0         | srv_database |
+----------+---------+---------------------+------+-----------+-----------+--------------+
| proxy    | RUNNING | 192.168.0.2 (eth0)  |      | CONTAINER | 0         | battlechine  |
+----------+---------+---------------------+------+-----------+-----------+--------------+
```

## Limitations
This software has been tested with a limited set of data and resources.

Specifically, it was tested against the official DHIS2 databases, which lack several type of data like metadata.
Also, audit data has been produced limited to basic processes like user management and authentication.

The system has been tested on laptops and workstations, using mostly virtualization and paravirtualization environments (i.e. VMWare and VirtualBox), with limited storage capacity.

All SIEM rules must be thoroughly tested to ensure correctness.

## Extend
If you want to add support to other type of containers like a different SIEM or a different monitoring system, you can do so by following the steps below:

1. Create two files in `containers` directory: one named with the new service you're implementing, and the second one with the `_postsetup` suffix. Format is `<name of the service>_<type of the service>`. For example, to implement a different SIEM like [OpenSearch](https://opensearch.org/), you would create the files `opensearch_siem` and `opensearch_siem_postsetup`.
2. Write the install and basic configuration steps in the main file and additional configuration steps in the postsetup script.
3. Add the relevant section in the `containers.json` file. The minimum fields you must include are `name`, `ip` and `type`. As `type`, you have to use the name of the main service file.

These are the minimum steps. You may want to add additional features in other scripts under `service` or add new ones to enrich and implement your service.

## How to contribute