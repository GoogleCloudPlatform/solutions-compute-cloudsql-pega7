#!/usr/bin/env bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

# This function retrieves a metadata attribute for the instance
function getMetadata(){
    local ATTRIBUTE=$1
    curl -s "http://metadata.google.internal/computeMetadata/v1/${ATTRIBUTE}" -H "Metadata-Flavor: Google"
}

# Required Project Settings
PROJECT_ID=$( getMetadata  "project/project-id" )
PROJECT_REGION=$( getMetadata  "project/attributes/google-compute-default-region" )
GCS_BUCKET=$( getMetadata "instance/attributes/GCS_BUCKET" )

# Required Cloud SQL Settings
ADMIN_USER_PW=$( getMetadata "instance/attributes/ADMIN_USER_PW" )
BASE_USER_PW=$( getMetadata "instance/attributes/BASE_USER_PW" )
SQL_INSTANCE_ID=$( getMetadata "instance/attributes/SQL_INSTANCE_ID" )

# Required Pega Settings
PEGA_ADMIN_PW=$( getMetadata "instance/attributes/PEGA_ADMIN_PW" )
PEGA_INSTALL_FILENAME=$( getMetadata "instance/attributes/PEGA_INSTALL_FILENAME" )

# Required Tomcat Settings
TOMCAT_HOME=/opt/tomcat
TOMCAT_USER=tomcat
TOMCAT_URL=https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.34/bin/apache-tomcat-8.5.34.tar.gz

# Default values shown below. Uncomment and change as desired.

# JAVA_HOME=/usr/lib/jvm/jre-openjdk/
# CLOUD_SQL_DIR=/opt/cloud_sql
# PEGA_DIR=/opt/pega

# Postgres Driver Version
# PG_DRIVER_URL="https://jdbc.postgresql.org/download/"
# PG_DRIVER_JAR=postgresql-42.2.4.jar

# Database Defaults
# ADMIN_USER=PegaADMIN
# BASE_USER=PegaBASE
# RULES_SCHEMA=pegarules
# DATA_SCHEMA=pegadata
# DBNAME=postgres
# PEGA_SYSTEM_NAME=pega
# PROD_LEVEl=2

# Error checking

# This function takes a variable name and checks if it exists. When there is an error we return nonzero and the entire process exits
function assertVar () {
    local VARNAME=$1
    [ -z "${!VARNAME}" ] && { echo "${VARNAME} must be set" >&2 ; return 1;}
    return 0
}

assertVar PROJECT_ID
assertVar PROJECT_REGION
assertVar SQL_INSTANCE_ID
assertVar ADMIN_USER_PW
assertVar BASE_USER_PW
[ -z "${JAVA_HOME}" ] && JAVA_HOME=/usr/lib/jvm/jre-openjdk/
[ -z "${CLOUD_SQL_DIR}" ] && CLOUD_SQL_DIR=/opt/cloud_sql
[ -z "${PEGA_DIR}" ] &&  PEGA_DIR=/opt/pega
[ -z "${PG_DRIVER_URL}" ] &&  PG_DRIVER_URL="https://jdbc.postgresql.org/download"
[ -z "${PG_DRIVER_JAR}" ] &&  PG_DRIVER_JAR=postgresql-42.2.4.jar
[ -z "${ADMIN_USER}" ] &&  ADMIN_USER=PegaADMIN
[ -z "${BASE_USER}" ] &&  BASE_USER=PegaBASE
[ -z "${RULES_SCHEMA}" ] &&  RULES_SCHEMA=pegarules
[ -z "${DATA_SCHEMA}" ] &&  DATA_SCHEMA=pegadata
[ -z "${DBNAME}" ] &&  DBNAME=postgres
[ -z "${PEGA_SYSTEM_NAME}" ] &&  PEGA_SYSTEM_NAME=pega
[ -z "${PROD_LEVEL}" ] &&  PROD_LEVEL=2


# Check instance tag to see if this server is a pega app server or not. If so, the initial pega admin pw is not needed.

if getMetadata "instance/tags" | grep -q pega-app ; then
  echo "Admin password not required"
else
  assertVar PEGA_ADMIN_PW 
  echo "Admin password found"
fi