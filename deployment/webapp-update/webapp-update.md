# Updating a Deployed JVM Web Application

This guide describes the routine deployment of a new version of a JVM web application to a Linux machine after the application and its production infrastructure have already been installed.

It assumes the server was prepared using the `linux-webapp-deployment` guide and that the application:

- is deployed as a JAR under `/opt`
- runs as a systemd service
- uses PostgreSQL and Liquibase
- has a `migrateDatabase.sh` script that backs up the database before migration
- is exposed through nginx and HTTPS

Replace all `<...>` placeholders with values appropriate to the application.

Concrete examples are given for a blagger service

* <LOCAL_JAR_PATH> = blagger-web/build/libs/blagger-web-1.0-SNAPSHOT-all.jar
* <APP_JAR> = blagger.jar
* <SSH_USER> = david
* <SERVER> = pi4b-8gb
* <SERVICE_NAME> = blagger
* <DEPLOYMENT_NAME> = blagger_prod/

---

## Deployment sequence

The normal deployment sequence is:

```text
build and test
→ copy new JAR to server
→ stop application
→ back up currently deployed JAR
→ install new JAR
→ run database migration
→ start application
→ verify service
→ smoke test
```

Stopping the application before replacing the JAR and migrating the database prevents the 
old application version from serving requests against a schema that may have changed.

## Build and test

Build the release JAR locally from the project root.

```bash
./gradlew build
```

Only deploy after a successful build and test run. It's probably worth committing changes 
to the project repos too.

## Copy the new JAR to the server

Copy the new application JAR to the login user's home directory on the destination machine.

```bash
scp <LOCAL_JAR_PATH> <SSH_USER>@<SERVER>:~/<APP_JAR>
```

```bash
scp blagger-web/build/libs/blagger-web-1.0-SNAPSHOT-all.jar david@pi4b-8gb:~/blagger.jar
```



Do not copy directly over the deployed JAR. Stage it outside the deployment directory first.

## Open an SSH shell on the server

```bash
ssh <SSH_USER>@<SERVER>
```

For example:
```bash
ssh david@pi4b-8gb
```

## Stop the application

```bash
sudo systemctl stop <SERVICE_NAME>
```

For example 
```bash 
sudo systemctl stop blagger
```

Verify:

```bash
sudo systemctl is-active <SERVICE_NAME>
```

For example 
```bash 
sudo systemctl is-active blagger
```

The expected result is `inactive`.

## Back up the currently deployed JAR

Preserve the current JAR before replacing it:

```bash
sudo cp \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR> \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/backups/<APP_JAR>-$(date +"%Y%m%d-%H%M%S")
```

For example:
```bash
sudo cp \
    /opt/blagger/deployments/blagger_prod/blagger.jar \
    /opt/blagger/deployments/blagger_prod/backups/blagger.jar-$(date +"%Y%m%d-%H%M%S")
```


This provides the application binary required for rollback. The `backups` directory is also used by `migrateDatabase.sh` for pre-migration database backups.

Verify if required:

```bash
sudo ls -lh /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/backups/
```

Concretely
sudo ls -lh /opt/blagger/deployments/blagger_prod/backups/


## Install the new JAR

```bash
sudo install \
    --owner=jvmapps \
    --group=appmgr \
    --mode=644 \
    ~/<APP_JAR> \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
```

Concretely
```bash
sudo install \
    --owner=jvmapps \
    --group=appmgr \
    --mode=644 \
    ~/blagger.jar \
    /opt/blagger/deployments/blagger_prod/blagger.jar
```

Verify:

```bash
sudo ls -l /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
```

Concretely:
```bash
sudo ls -l /opt/blagger/deployments/blagger_prod/blagger.jar
```

It should be owned by `jvmapps:appmgr`.

## Run database migration

Run the application's migration script for every deployment, even when no schema change is expected:

```bash
sudo -u jvmapps \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/migrateDatabase.sh
```

Concretely:

```bash
sudo -u jvmapps \
    /opt/blagger/deployments/blagger_prod/migrateDatabase.sh
```

The migration script should:

1. create a timestamped backup of the current production database
2. run Liquibase using the newly installed application JAR
3. apply any outstanding changesets
4. succeed harmlessly when there are no outstanding changesets

Ensure migration completes successfully before starting the application.

If migration fails, do not start the new application until the failure has been understood and either corrected or rolled back.

## Start the application

```bash
sudo systemctl start <SERVICE_NAME>
sudo systemctl is-active <SERVICE_NAME>
```

Concretely:
```bash
sudo systemctl start blagger
sudo systemctl is-active blagger
```


The expected result is `active`.

Inspect full status if required:

```bash
sudo systemctl status <SERVICE_NAME> --no-pager
```

Concretely:

```bash
sudo systemctl status blagger --no-pager
```

## Check startup logs

Review recent systemd output:

```bash
sudo journalctl -u <SERVICE_NAME> -n 50 --no-pager
```

Concretely
```bash
sudo journalctl -u blagger -n 50 --no-pager
```

Look for successful database connection, Liquibase/schema verification, web-server startup, and binding to the expected HTTP port.

If the application has its own log:

```bash
sudo ls -l /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs/
sudo tail -n 20 /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/logs/<APP_LOG>
```

Application log files must remain writable by `jvmapps`.

## Smoke test

Test through the normal public HTTPS URL rather than only the local HTTP port.

Verify at least:

- the HTTPS URL loads
- authentication succeeds, if applicable
- the main application page loads
- existing production data is present
- the published release notes show the expected release number, date and changes, if the application exposes release notes
- a small representative application operation succeeds
- application logs contain no unexpected errors

For Blagger, open `/documents/release-notes` and confirm that the newest section matches the release being deployed.

The functional smoke test should be application-specific.

## Clean up the staged JAR

Once deployment succeeds:

```bash
rm ~/<APP_JAR>
```

Do not remove the timestamped previous JAR or pre-migration database backup until there is confidence that the deployment is stable.

## Rollback

A deployment may involve two independent changes: the application JAR and the database schema.

### Stop the failed application

```bash
sudo systemctl stop <SERVICE_NAME>
```

### Restore the previous JAR

Identify the timestamped JAR created immediately before deployment:

```bash
sudo ls -lt /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/backups/
```

Restore it:

```bash
sudo install \
    --owner=jvmapps \
    --group=appmgr \
    --mode=644 \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/backups/<PREVIOUS_JAR_BACKUP> \
    /opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/<APP_JAR>
```

### Consider whether the database must also be restored

If no Liquibase changesets were applied, restoring the previous JAR may be sufficient.

If the deployment changed the schema, determine whether the previous application version is compatible with the migrated schema. Do not assume that reversing a database migration is safe.

If the database must be restored, use the pre-migration backup created by `migrateDatabase.sh`. Restoring it also restores production data to the time of that backup, so data written after migration will be lost.

Follow the database restore procedure in the Linux web application deployment guide.

### Restart and verify

```bash
sudo systemctl start <SERVICE_NAME>
sudo systemctl status <SERVICE_NAME> --no-pager
```

Repeat the normal smoke test.

## Deployment checklist

- [ ] Local build succeeds
- [ ] Tests pass
- [ ] New JAR copied to server
- [ ] Application stopped
- [ ] Previous JAR backed up
- [ ] New JAR installed with correct ownership
- [ ] `migrateDatabase.sh` succeeds
- [ ] Pre-migration database backup exists
- [ ] Application starts successfully
- [ ] systemd reports the service active
- [ ] Startup logs contain no unexpected errors
- [ ] HTTPS smoke test passes
- [ ] Published release notes match the expected release, if applicable
- [ ] Representative application operation succeeds
- [ ] Staged JAR removed
