#!/usr/bin/env bash
# TEMPLATE - replace all <...> placeholders before use.
set -euo pipefail

readonly DeploymentDirectory="/opt/<APP_NAME>/deployments/<DEPLOYMENT_NAME>"

mkdir -p "$LogFilePath"

exec /usr/bin/java \
    -DDeployment="$Deployment" \
    -DDatabaseHost="$DatabaseHost" \
    -DDatabasePort="$DatabasePort" \
    -DDatabaseName="$DatabaseName" \
    -DDatabaseUserName="$DatabaseUserName" \
    -DDatabaseUserPassword="$DatabaseUserPassword" \
    -DWebAppServerHttpPort="$WebAppServerHttpPort" \
    -DWebAppUserName="$WebAppUserName" \
    -DWebAppUserPassword="$WebAppUserPassword" \
    -DLogFilePath="$LogFilePath" \
    -cp "$DeploymentDirectory/<APP_JAR>" \
    <WEBAPP_MAIN_CLASS>
