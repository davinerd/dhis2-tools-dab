# Container types
This page contains the list of all supported container types, alongside specific configurations, divided by components.

All container types share the same base structure:
```
{
    "name": <container name>,
    "ip": <IP to assign>,
    "type": <container type>
}
```

Some types allow extra keys for more control. You can read more about it in each container type's key reference section.


## Proxy
The proxy container sits in front of the DHIS2 container, and it ensures scalability, performance and security to the underlining DHIS2 system: it's the interface between the public internet and the LXD hosts.

### apache_proxy
The `apache_proxy` container type spins an Apache2 container enabling ssl, cache, rewrite, proxy and headers modules.

A [basic configuration file](../setup/configs/apache-dhis2.conf) is used as a template to be further modified by the postsetup script.

#### Examples
```
{
    "name": "proxy",
    "ip": "192.168.0.2",
    "type": "apache_proxy"
}
```

#### Key reference
No additional keys can be specified at this time.


### nginx_proxy
The `nginx_proxy` container type spins a nginx container configuring ssl, performance and gzip modules.

A [basic configuration file](../setup/configs/nginx-dhis2.conf) is used as a template to be further modified by the postsetup script.

#### Examples
```
{
    "name": "proxy",
    "ip": "192.168.0.2",
    "type": "nginx_proxy"
}
```

#### Key reference
No additional keys can be specified at this time.

## Database
DHIS2 stores all data into a database: it's a critical part which cannot be omitted.

Currently, DHIS2 supports only PostgreSQL due to its SQL queries structure and extensions used.

### postgres
The `postgres` container type creates a container with PostgreSQL 13 and all the necessary extensions needed for DHIS2 to work.

#### Examples
```
{
    "name": "postgres",
    "ip": "192.168.0.20",
    "type": "postgres"
}
```

#### Key reference
No additional keys can be specified at this time.


### postgres12
This container type creates a PostgreSQL 12 container. It acts the same as the `postgres` type.

**We do not recommend this type and use the `postgres` instead.**

#### Examples
```
{
    "name": "postgres",
    "ip": "192.168.0.20",
    "type": "postgres12"
}
```

#### Key reference
No additional keys can be specified at this time.

## Monitoring
Monitoring computing resources like CPU, memory and disk usage is paramount for the successful deployment of a robust DHIS2 infrastructure.

It's therefore that we provide monitoring capabilities within the infrastructure so people can monitor and alert in case resources become an issue.

### munin_monitor
This container type configures the `munin` monitoring system: it installs the required services and configure the proxy (would that be apache2 or nginx) to serve its dashboard, being effectively protected by the proxy as well.

Credentials are setup thanks to [`dhis2-set-credentials`](./service_scripts.md#dhis2-set-credential) tool.

#### Examples
```
{
    "name": "monitor",
    "ip": "192.168.0.30",
    "type": "munin_monitor"
}
```

#### Key reference
No additional keys can be specified at this time.



## SIEM
A Security Information Event Monitoring (SIEM) system is a centralized collector of logs coming from resources you want to monitor for troubleshooting and, most importantly, security issues: its goal is to make all logs centralized for easy querying, allowing people to quickly identify issues, would that be manually or in an automated fashion.

A SIEM infrastructure typically consists of agents installed on systems to monitor in order to extract logs and ship them to the central system, where a dashboard is typically present to help people analyze and investigate events.

### es_siem
The container type `es_siem` configures an Elasticsearch container to collect and analyze logs coming from all containers.

It does so with the help of [filebeat](https://www.elastic.co/beats/filebeat), which is configured automatically for every running container. It's configured to extract logs from the journal, and in doing so it configures all systems to log to the journald service (thanks to [`dhis2-set-journal` script](./service_scripts.md#dhis2-set-journal)).

The container type installs elasticsearch, logstash and kibana from the official Elastic repository. The postsetup script configures journal and filebeat in every running container (thanks to [`dhis2-set-elasticsearch` script](./service_scripts.md#dhis2-set-elasticsearch)).

Additional configuration files can be found in `setup/configs/es_siem`. Files are divided in directories based on their function, and executed in the postsetup script.

#### Built in configuration
By default, the `es_siem_postsetup` script configures:
* an ingest pipeline to parse the `message` field into JSON object
* a data view for the default index
* an index to collect alerts
* a data view for the alert index
* alert rules

#### Examples
```
{
    "name": "siem",
    "ip": "192.168.0.201",
    "type": "es_siem"
}
```

#### Key reference
No additional keys can be specified at this time.


## Logger
The logger is a centralized container for logs from all containers: the goal is to increase security and integrity of logs in case troubleshooting or a security investigation is needed.

### journal_logger
The container type `journal_logger` configures all containers to log into the journal (via the `journald` system).

Logs are shipped via the `systemd-journal-remote` service through an HTTP connection, installed and configured in each container via the postsetup script (except for the SIEM container).

Logs are saved in one of the supported backends, as described below.

#### fs backend
When `storage: fs`, the logger container will save logs into the host's location specified by the `directory` key, which must be present before launching the script.

LXD will create a pool and a volume within such pool (both values are hardcoded in [journal_logger_postsetup](../setup/containers/journal_logger_postsetup)) and attached to the container in the `CONTAINER_LOGS_DIR` (hardcoded to `/var/log/journal/remote`).

Logs arriving through the `systemd-journal-remote` will be collected and saved on the host's directory, under ` `, with the format ` `.


#### s3 backend
When `storage: s3`, the logger container will ship logs into an S3 bucket via [`s3cmd`](https://s3tools.org/s3cmd) tool.

The container can be configured by specifying a working [s3cfg file](https://s3tools.org/kb/item14.htm) or by configuring the access and secret keys.

When using an user-supplied s3cfg, all other keys are ignored: the s3cmd configuration file is pushed into the container and used by s3cmd.

When configuring the access and secret keys, the additional provider and location keys must be configured as well, in order for s3cmd to correctly upload the data.

For the list of supported S3 providers, please refer to the [Keys Reference](#keys-reference) section.

Please note that, due to the integrity checks on S3 and how the journal works, it's not possible to stream such logs directly to S3. A copy of the logs must be performed and then uploaded.
To achieve this, a script called `s3backup.sh` (saved at `/usr/local/bin/` on the container) is generated at runtime and saved as cron job to perform a backup to S3 every 5 minutes.

#### Examples
```
{
    "name": "logger",
    "ip": "192.168.0.100",
    "type": "journal_logger",
    "storage": "fs",
    "directory": "/mnt/logs"
}
```

For an S3 backend:

```
{
    "name": "logger",
    "ip": "192.168.0.100",
    "type": "journal_logger",
    "storage": "s3",
    "directory": "my-logs-bucket",
    "access_key": "AXXXXXXXXXX",
    "secret_key": "YYYYYYYYYYY",
    "provider": "contabo",
    "location": "EU"
}
```

#### Keys reference

|   KEY    |  VALUES        |    DEFAULT      | MANDATORY | DESCRIPTION            |
|----------|----------------|-----------------|-----------|------------------------|
| directory| String         | `N/A`           |   Y       | Path to the directory on the host or S3 bucket name |
| storage  | [`fs`, `s3`]   | `fs`            |   N       | Backend system to use |

When `storage: s3`, additional keys can be specified. Please note that one of `config` or the `access_key` and `secret_key` keys must be specified.

|   KEY     |  VALUES       |    DEFAULT      | MANDATORY | DESCRIPTION            |
|-----------|---------------|-----------------|-----------|------------------------|
| config    | String        | `N/A`           |   N       | Absolute path to an s3cfg file. When specified, `access_key`, `secret_key` and `location` will be ignored. |
| access_key| String        | `N/A`           |   N       | The access key to access the S3 bucket. |
| secret_key| String        | `N/A`           |   N       | The secret key to access the S3 bucket. |
| provider  | [`aws`, `gcp`, `linode`, `digitalocean`, `contabo` ]        | `aws`           |   N       | The provider to use. |
| location  | String        | `eu-west-1`     |   N       | The region where the S3 bucket resides. |

