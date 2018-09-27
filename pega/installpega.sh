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
############ All Code below this line. Edit with care ###############

# Load Environment Variables, exit if there is a failure
echo "Checking required variables"
source pega/env.sh

echo "All variables set properly, continuing...."

# Install stackdriver logging and monitoring components
echo "Installing stackdriver logging"
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

echo "Installing stackdriver monitoring agent"
curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
bash install-monitoring-agent.sh

# Install required components
echo "Installing required components and updates"
yum -y -q update
yum -y -q install wget unzip java-1.8.0-openjdk-devel postgresql.x86_64

# Shut down and disable local firewall, we will use GCP firewall instead
echo "Shutting down firewalld"
systemctl stop firewalld.service
systemctl disable firewalld.service

# Install cloudsql proxy
echo "Installing cloudsql proxy"
mkdir "${CLOUD_SQL_DIR}"
wget -nv https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O "${CLOUD_SQL_DIR}/cloud_sql_proxy"
chmod +x "${CLOUD_SQL_DIR}/cloud_sql_proxy"

cp systemd/cloud_sql_proxy.service /etc/systemd/system/

sed -i "s|NAME_REPLACE|Environment=INSTANCE_CONNECTION_NAME=${PROJECT_ID}:${PROJECT_REGION}:${SQL_INSTANCE_ID}|g" /etc/systemd/system/cloud_sql_proxy.service

systemctl daemon-reload
systemctl enable cloud_sql_proxy.service

# Run cloud sql proxy
systemctl start cloud_sql_proxy
sleep 2
systemctl is-active cloud_sql_proxy --quiet || { echo "Cloud SQL Proxy did not start properly, exiting…" >&2; exit 1; }

# Download pega installation media
echo "Downloading pega installation media, please wait...."
mkdir -p "${PEGA_DIR}"
gsutil cp "gs://${GCS_BUCKET}/*${PEGA_INSTALL_FILENAME}" "${PEGA_DIR}/"
cd "${PEGA_DIR}"
echo "Unzipping pega installation media, please wait...."
unzip -q -o "${PEGA_INSTALL_FILENAME}"

# Run checksum
# Remove 7 unneeded lines at beginning of checksum file
sed -ie '1,7d' .checksum/*.md5
md5sum -c .checksum/*.md5 --quiet || { echo "Installation file did not pass checksum and might be corrupt. Please retry."; exit 1; }

# Set setup properties for install on cloud sql
echo "Setting variables in setupDatabase.properties file"
sed -i "s|user.temp.dir|user.temp.dir=${PEGA_DIR}|g" "${PEGA_DIR}/scripts/setupDatabase.properties"
sed -i 's/bypass.udf.generation/bypass.udf.generation=true/g' "${PEGA_DIR}/scripts/setupDatabase.properties"

# Download postgres jdbc driver
echo "Downloading postgres jdbc driver"
wget -nv "${PG_DRIVER_URL}/${PG_DRIVER_JAR}"

# Install Pega
echo "Creating Pega Schemas"
# Create pega schemas

PGPASSWORD="${ADMIN_USER_PW}" psql -d "postgresql://localhost:5432/${DBNAME}" -U "${ADMIN_USER}" <<EOF
CREATE SCHEMA ${RULES_SCHEMA};
CREATE SCHEMA ${DATA_SCHEMA};
GRANT USAGE ON SCHEMA ${DATA_SCHEMA} TO "${BASE_USER}";
GRANT USAGE ON SCHEMA ${RULES_SCHEMA} TO "${BASE_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA ${DATA_SCHEMA} GRANT ALL ON TABLES TO "${BASE_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA ${RULES_SCHEMA} GRANT ALL ON TABLES TO "${BASE_USER}";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${DATA_SCHEMA} TO "${BASE_USER}";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${RULES_SCHEMA} TO "${BASE_USER}";
EOF

cd "${PEGA_DIR}/scripts"

echo "Starting pega database installation script, this will take 30-60 minutes."
JAVA_HOME="${JAVA_HOME}" "${PEGA_DIR}/scripts/install.sh" \
	--driverClass org.postgresql.Driver \
	--driverJAR "${PEGA_DIR}/${PG_DRIVER_JAR}" \
	--dbType postgres --dbURL "jdbc:postgresql://localhost:5432/${DBNAME}" \
	--dbUser "${ADMIN_USER}" \
	--dbPassword "${ADMIN_USER_PW}" \
	--rulesSchema "${RULES_SCHEMA}" \
	--dataSchema "${DATA_SCHEMA}" \
	--systemName "${PEGA_SYSTEM_NAME}" \
	--productionLevel "${PROD_LEVEL}" \
	--adminPassword "${PEGA_ADMIN_PW}";

if [ $? -ne 0 ]
 then
   echo "There was an error during installation. Please review the logs, wipe the database and try again."
 else
  echo "Your Pega installation is complete!"
fi
