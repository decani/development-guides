#!/usr/bin/env bash
# TEMPLATE - replace <APP_NAME> and add required application-specific properties.
# systemd loads config/webApp.env; this script does not source it.
set -euo pipefail

readonly deploymentDirectory="/opt/dks/<APP_NAME>"

exec /usr/bin/java \
    -DDeployment="$Deployment" \
    -DDatabaseHost="$DatabaseHost" \
    -DDatabasePort="$DatabasePort" \
    -DDatabaseName="$DatabaseName" \
    -DDatabaseUserName="$DatabaseUserName" \
    -DDatabaseUserPassword="$DatabaseUserPassword" \
    -DWebAppServerHttpPort="$WebAppServerHttpPort" \
    -DLogFilePath="$LogFilePath" \
    -jar "$deploymentDirectory/app.jar"
