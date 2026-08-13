#!/usr/bin/env bash
# TEMPLATE - replace all <...> placeholders before use.
set -euo pipefail

ConfigFile="/opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>/config/webApp.env"
DeploymentDirectory="/opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>"

if [[ ! -r "$ConfigFile" ]]; then
    echo "Cannot read configuration file: $ConfigFile" >&2
    exit 1
fi

source "$ConfigFile"

cd "$DeploymentDirectory"

mkdir -p "$LogFilePath"

BackupDirectory="$DeploymentDirectory/backups"
mkdir -p "$BackupDirectory"

BackupTimestamp=$(date +"%Y%m%d-%H%M%S")
BackupFilename="$BackupDirectory/${DatabaseName}-pre-migrate-database-backup-${BackupTimestamp}.sql"

echo "Backing up database..."

PGPASSWORD="$DatabaseUserPassword" \
pg_dump \
    -h "$DatabaseHost" \
    -p "$DatabasePort" \
    -U "$DatabaseUserName" \
    --no-owner \
    --no-privileges \
    "$DatabaseName" \
    > "$BackupFilename"

echo "Database backed up to:"
echo "  $BackupFilename"

java \
    -DDatabaseHost="$DatabaseHost" \
    -DDatabasePort="$DatabasePort" \
    -DDatabaseUserName="$DatabaseUserName" \
    -DDatabaseUserPassword="$DatabaseUserPassword" \
    -DDatabaseName="$DatabaseName" \
    -DLogFilePath="$LogFilePath" \
    -cp "./<APP_JAR>" \
    <MIGRATE_MAIN_CLASS> \
    "$@"
