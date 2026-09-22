#!/usr/bin/env bash
# TEMPLATE - replace <APP_NAME> and <MIGRATE_MAIN_CLASS>.
set -euo pipefail
umask 077

readonly deploymentDirectory="/opt/dks/<APP_NAME>"
readonly configFile="$deploymentDirectory/config/webApp.env"

if [[ ! -r "$configFile" ]]; then
    echo "Cannot read configuration: $configFile" >&2
    exit 1
fi

source "$configFile"
cd "$deploymentDirectory"

readonly backupFile="$deploymentDirectory/backups/${DatabaseName}-pre-migrate-$(date +%Y%m%d-%H%M%S).sql"

echo "Backing up $DatabaseName..."
PGPASSWORD="$DatabaseUserPassword" pg_dump \
    -h "$DatabaseHost" \
    -p "$DatabasePort" \
    -U "$DatabaseUserName" \
    --no-owner \
    --no-privileges \
    -f "$backupFile" \
    "$DatabaseName"

echo "Database backed up to $backupFile"
/usr/bin/java \
    -DDatabaseHost="$DatabaseHost" \
    -DDatabasePort="$DatabasePort" \
    -DDatabaseName="$DatabaseName" \
    -DDatabaseUserName="$DatabaseUserName" \
    -DDatabaseUserPassword="$DatabaseUserPassword" \
    -DLogFilePath="$LogFilePath" \
    -cp "$deploymentDirectory/app.jar" \
    <MIGRATE_MAIN_CLASS>
