# Deploying a JVM Web Application to Linux

This guide describes how to deploy a JVM web application to a Linux machine as a production service.

The resulting application:

- runs as a dedicated service user
- uses PostgreSQL
- starts automatically using systemd
- is exposed through nginx
- has a DNS hostname
- uses HTTPS with a Let's Encrypt certificate managed by Certbot
- can run alongside other web applications on the same machine

The examples use placeholders such as `<APP_NAME>`, `<DEPLOYMENT_NAME>` and `<HTTP_PORT>`. Replace every `<...>` placeholder before using a template.

Reusable templates are stored in [`files/`](files/):

- [`webApp.env`](files/webApp.env) - production environment values
- [`startWebApp.sh`](files/startWebApp.sh) - application launcher
- [`migrateDatabase.sh`](files/migrateDatabase.sh) - pre-migration backup and Liquibase launcher
- [`webapp.service`](files/webapp.service) - systemd unit
- [`webapp.conf`](files/webapp.conf) - nginx reverse-proxy configuration

## Install required software

This guide assumes Ubuntu Server 22.04+ or an equivalent Linux distribution.

For Ubuntu, update the package index:

```bash
sudo apt update
```

Install the required software:

```bash
sudo apt install \
    openjdk-17-jre \
    postgresql \
    nginx \
    certbot \
    python3-certbot-nginx
```

If the application requires a specific PostgreSQL major version that is not provided by the Ubuntu repositories, configure an appropriate PostgreSQL package repository and install that version instead.

Verify:

```bash
java -version
psql --version
nginx -v
certbot --version
```

The Java version must be compatible with the version used to build the application.

Do not mix a large operating-system or platform upgrade into an application deployment unless it is intentionally part of the work. A known-good host is a useful deployment baseline.

## Network prerequisites

The server must be reachable from the internet on:

- TCP port 80 for HTTP and Let's Encrypt certificate validation
- TCP port 443 for HTTPS

If the server is behind a router performing NAT, forward ports 80 and 443 to the Linux server.

Do not expose the application's JVM HTTP port or PostgreSQL port through the router.

Check the host firewall, if enabled:

```bash
sudo ufw status
```

Ensure SSH remains permitted before making firewall changes. Permit HTTP and HTTPS as appropriate for the host.

## Application user and group

Run JVM applications using a dedicated service account rather than a normal login user or `root`.

For example:

```bash
sudo groupadd appmgr
sudo useradd \
    --system \
    --no-create-home \
    --shell /usr/sbin/nologin \
    --gid appmgr \
    jvmapps
```

The same `jvmapps` account can run multiple trusted JVM applications on the machine.

The service account does not need a password or interactive login. Administrators edit deployment files using their normal account and `sudo`.

## Deployment directory

Create a production deployment directory:

```bash
sudo mkdir -p /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/{backups,config,logs}
```

A typical deployment is:

```text
/opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/
├── <APP_JAR>
├── startWebApp.sh
├── migrateDatabase.sh
├── config/
│   └── webApp.env
├── logs/
└── backups/
```

Set ownership and permissions appropriate to the application. For example:

```bash
sudo chown -R jvmapps:appmgr /opt/<APP_NAME>
sudo chmod 750 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>
sudo chmod 750 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config
sudo chmod 775 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs
sudo chmod 750 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/backups
```

Deployment scripts can instead be owned by `root:appmgr` and made executable by the group.

## PostgreSQL database

Create a dedicated PostgreSQL role and production database.

Open PostgreSQL as its administrative user:

```bash
sudo -u postgres psql
```

Create the application role:

```sql
create role <DATABASE_USER>
    login
    password '<DATABASE_PASSWORD>';
```

Create the database owned by that role:

```sql
create database <DATABASE_NAME>
    owner <DATABASE_USER>
    encoding 'UTF8'
    lc_collate 'en_GB.UTF-8'
    lc_ctype 'en_GB.UTF-8'
    template template0;
```

Exit `psql`:

```text
\q
```

Verify the result:

```bash
sudo -u postgres psql -c "\du"
sudo -u postgres psql -c "\l+ <DATABASE_NAME>"
sudo -u postgres psql -d <DATABASE_NAME> -c "\dn+"
```

Prove the application role can connect:

```bash
psql \
    -h localhost \
    -U <DATABASE_USER> \
    -d <DATABASE_NAME> \
    -c "select current_user, current_database();"
```

## Restoring an existing database

If production is being seeded from an existing environment, create a portable plain-SQL backup on the source machine:

```bash
pg_dump \
    -U "$DatabaseUserName" \
    -W \
    --no-owner \
    --no-privileges \
    -d "$DatabaseName" \
    -f <BACKUP_FILE>.sql
```

`--no-owner` and `--no-privileges` prevent source-environment ownership and grants from being replayed on the target.

Copy the backup to the production machine and restore it into an **empty** target database:

```bash
psql \
    -h localhost \
    -U <DATABASE_USER> \
    -d <DATABASE_NAME> \
    --single-transaction \
    -v ON_ERROR_STOP=1 \
    -f <BACKUP_FILE>.sql
```

`psql -f` does not make the complete script transactional by default and normally continues after SQL errors. `--single-transaction` plus `ON_ERROR_STOP=1` makes a restore fail cleanly rather than leaving a partially restored database.

Do not simply truncate an existing database before restoring a full dump. A full SQL dump contains schema objects such as tables, sequences and constraints. Recreate the target database if a clean restore is required.

If Liquibase tables are present in the source, the restore carries the existing migration history with it. Run the current migration afterwards to move the restored database forward.

## Production environment configuration

Copy [`files/webApp.env`](files/webApp.env) to:

```text
/opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config/webApp.env
```

**Replace every placeholder and add or remove application-specific properties as required.**

The environment file contains secrets, so restrict access:

```bash
sudo chown root:appmgr /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config/webApp.env
sudo chmod 640 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config/webApp.env
```

Do not commit real production passwords to git.

## Deploy the application JAR

Build the deployable JAR on the development machine and copy it to the Linux host, for example:

```bash
scp <APP_JAR> <ADMIN_USER>@<SERVER>:~/<APP_JAR>
```

Install it into the deployment directory:

```bash
sudo mv ~/<APP_JAR> /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
sudo chown jvmapps:appmgr /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
sudo chmod 640 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
```

## Database migration script

Copy [`files/migrateDatabase.sh`](files/migrateDatabase.sh) to the deployment directory **and replace its placeholders**.

It:

1. loads the production environment
2. creates a portable pre-migration database backup
3. runs the application's Liquibase migration entry point

Install it, for example:

```bash
sudo chown root:appmgr /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/migrateDatabase.sh
sudo chmod 750 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/migrateDatabase.sh
```

Run migration as the JVM service user:

```bash
sudo -u jvmapps /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/migrateDatabase.sh
```

Verify the migration history if needed:

```bash
psql \
    -h localhost \
    -U <DATABASE_USER> \
    -d <DATABASE_NAME> \
    -c "select id, author, filename, orderexecuted from databasechangelog order by orderexecuted;"
```

## Application startup script

Copy [`files/startWebApp.sh`](files/startWebApp.sh) to the deployment directory and replace its placeholders.

Make it executable:

```bash
sudo chown root:appmgr /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/startWebApp.sh
sudo chmod 750 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/startWebApp.sh
```

systemd will load the environment file automatically. For a manual test, explicitly load it first:

```bash
sudo -u jvmapps bash -c '
set -a
source /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config/webApp.env
set +a
exec /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/startWebApp.sh
'
```

Verify the application responds on its local port:

```bash
curl -I http://127.0.0.1:<HTTP_PORT>/
```

A `401 Unauthorized` response can be a successful test if the application uses Basic Auth.

Stop the manually started application before configuring systemd.

## systemd service

Copy [`files/webapp.service`](files/webapp.service) to:

```text
/etc/systemd/system/<APP_NAME>.service
```

**Replace its placeholders**, then load, enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable <APP_NAME>
sudo systemctl start <APP_NAME>
sudo systemctl status <APP_NAME> --no-pager
```

View logs with:

```bash
sudo journalctl -u <APP_NAME>
```

The `EnvironmentFile=` entry supplies the environment to `startWebApp.sh`; the startup script does not source the file itself.

## DNS

Choose a hostname for the application, for example:

```text
<HOSTNAME> = myapp.example.com
```

At the DNS provider, create an appropriate record pointing the hostname at the public IP address of the Linux server. For IPv4 this will normally be an `A` record.

Creating the DNS entry before nginx and Certbot is useful because DNS can propagate while the application deployment progresses.

Verify resolution before requesting the HTTPS certificate:

```bash
getent hosts <HOSTNAME>
```

The hostname should resolve to the server's public IP.

## nginx reverse proxy

Each JVM application should use its own local HTTP port. nginx exposes applications through separate hostnames on the normal HTTP/HTTPS ports.

For example:

```text
myapp.example.com -> nginx -> 127.0.0.1:7002
```

The application's JVM HTTP port should not be exposed publicly.

Copy [`files/webapp.conf`](files/webapp.conf) to:

```text
/etc/nginx/sites-available/<APP_NAME>
```

Replace `<HOSTNAME>` and `<HTTP_PORT>`.

Enable the site:

```bash
sudo ln -s \
    /etc/nginx/sites-available/<APP_NAME> \
    /etc/nginx/sites-enabled/<APP_NAME>
```

Test the nginx configuration:

```bash
sudo nginx -t
```

Then reload nginx:

```bash
sudo systemctl reload nginx
```

Verify nginx is routing the hostname to the application:

```bash
curl -I -H 'Host: <HOSTNAME>' http://127.0.0.1/
```

A `401 Unauthorized` response can be a successful test if the application uses Basic Auth.

## HTTPS with Certbot

Once DNS resolves correctly and nginx serves the hostname, request a certificate:

```bash
sudo certbot --nginx -d <HOSTNAME>
```

Certbot obtains and installs the Let's Encrypt certificate, updates nginx for HTTPS, and configures automatic renewal.

Verify externally:

```bash
curl -I https://<HOSTNAME>/
```

Then test the application in a browser.

For PWAs, HTTPS is also required for normal service-worker/installability behaviour.

## Verify automatic startup

Reboot the Linux machine:

```bash
sudo reboot
```

Do not assume the JVM applications have failed merely because SSH is already available. PostgreSQL and the applications may still be initialising. Allow sufficient time for the boot to settle before diagnosing a failure.

Then check:

```bash
sudo systemctl status <APP_NAME> --no-pager
```

The service should report:

```text
Active: active (running)
```

Verify the public HTTPS URL again. If several applications share the host, verify them all after reboot.

## Optional: PostgreSQL access from the LAN

The application itself should normally connect to PostgreSQL using `localhost`.

For occasional production maintenance, PostgreSQL can also be made accessible from trusted machines on the local network.

Configure PostgreSQL to listen on the server's private network address as well as localhost, for example:

```text
listen_addresses = 'localhost,192.168.0.20'
```

Add a suitably restricted `pg_hba.conf` rule, for example:

```text
host    <DATABASE_NAME>    <DATABASE_USER>    192.168.0.0/24    scram-sha-256
```

Restart or reload PostgreSQL as required.

This can be useful for trusted development tools such as IntelliJ Database Tools or DBeaver.

**Do not expose PostgreSQL through the internet-facing router or firewall.**

## Troubleshooting

### Application is not yet active after reboot

Wait for the machine to finish initialising, then inspect the current boot journal:

```bash
sudo journalctl -b -u <APP_NAME> --no-pager
```

### Application cannot write its log file

Check both the log directory and existing log-file ownership:

```bash
sudo ls -ld /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs
sudo ls -l /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs
```

An existing file accidentally created by `root` may be unwritable by `jvmapps` even when the directory permissions are correct.

Fix ownership rather than making logs world-writable:

```bash
sudo chown jvmapps:appmgr /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs/<LOG_FILE>
```

### Database restore partially succeeds

Drop and recreate the target database if it contains a failed partial restore, then repeat the restore using:

```text
--single-transaction -v ON_ERROR_STOP=1
```

### Restored SQL references a source database role

Regenerate the source backup using:

```text
--no-owner --no-privileges
```

Do not create development-only roles on the production machine merely to satisfy ownership statements in a dump.

## Next: routine application updates

This guide covers the initial Linux deployment. Keep the normal application update procedure separate and shorter: build/copy the new JAR, take a backup, migrate, restart the systemd service, and verify the application.
