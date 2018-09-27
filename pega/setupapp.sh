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

[ -d "${TOMCAT_HOME}" ] && { echo "Install script already ran, exiting."; exit 1; }

echo "All variables set properly, continuing...."

# Install stackdriver logging and monitoring components
echo "Installing stackdriver logging"
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

echo "Installing stackdriver monitoring agent"
curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
bash install-monitoring-agent.sh

# Install required components
echo "Updating packages and installing required packages"
yum -y -q update
yum -y -q install wget unzip java-1.8.0-openjdk-devel

# Shut down and disable local firewall, we will use GCP firewall instead!
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

# Create application directories
mkdir "${PEGA_DIR}"
mkdir "${PEGA_DIR}/tmp"
mkdir "${TOMCAT_HOME}"

# Install Tomcat
echo "Installing Tomcat"
useradd -M -s /bin/nologin -d "${TOMCAT_HOME}" "${TOMCAT_USER}"
wget -nv "${TOMCAT_URL}"
tar -zxf apache-tomcat-*.tar.gz -C "${TOMCAT_HOME}" --strip-components=1

echo "Install Tomcat stackdriver monitoring/logging"
wget -nv https://raw.githubusercontent.com/Stackdriver/stackdriver-agent-service-configs/master/etc/collectd.d/tomcat-7.conf -P /opt/stackdriver/collectd/etc/collectd.d/
systemctl restart google-fluentd

ln -s "${TOMCAT_HOME}/logs" /var/log/tomcat

systemctl restart stackdriver-agent

# Download postgres jdbc driver
echo "Installing postgres jdbc driver"
wget -nv "${PG_DRIVER_URL}/${PG_DRIVER_JAR}" -O "${TOMCAT_HOME}/lib/${PG_DRIVER_JAR}"

# Change ownership of app dir to tomcat user.
chown -R "${TOMCAT_USER}:${TOMCAT_USER}" "${TOMCAT_HOME}" "${PEGA_DIR}"

# Setup systemd
cp systemd/tomcat.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable tomcat.service
systemctl start tomcat

# Setup tomcat with pega required settings
echo "Installing Pega components"
cp -rf tomcat/. "${TOMCAT_HOME}"

# Replace users and passwords
sed -i "s|pegabase|${BASE_USER}|g" "${TOMCAT_HOME}/conf/context.xml"
sed -i "s|pegaadmin|${ADMIN_USER}|g" "${TOMCAT_HOME}/conf/context.xml"
sed -i "s|basepw|${BASE_USER_PW}|g" "${TOMCAT_HOME}/conf/context.xml"
sed -i "s|adminpw|${ADMIN_USER_PW}|g" "${TOMCAT_HOME}/conf/context.xml"
sed -i "s|/opt/pega/tmp|${PEGA_DIR}/tmp|g" "${TOMCAT_HOME}/conf/context.xml"
sed -i "s|<index_directory>|${PEGA_DIR}/tmp|g" "${TOMCAT_HOME}/bin/setenv.sh"

# Install prweb.war/prhelp/prsysmgmt file
mkdir "${PEGA_DIR}/install"
echo "Downloading pega archive, this may take a few moments....."
gsutil cp "gs://${GCS_BUCKET}/*${PEGA_INSTALL_FILENAME}" "${PEGA_DIR}/install"
echo "Unzipping pega archive..."
unzip -q "${PEGA_DIR}/install/*${PEGA_INSTALL_FILENAME}" -d "${PEGA_DIR}/install"

cd "${PEGA_DIR}"/install
sed -ie '1,7d' .checksum/*.md5
md5sum -c .checksum/*.md5 --quiet || { echo "Installation file did not pass checksum and might be corrupt. Please retry."; exit 1; }

echo "Installing pega .war files..."
cp "${PEGA_DIR}/install/archives/prweb.war" "${TOMCAT_HOME}/webapps"
cp "${PEGA_DIR}/install/archives/prhelp.war" "${TOMCAT_HOME}/webapps"
cp "${PEGA_DIR}/install/archives/prsysmgmt.war" "${TOMCAT_HOME}/webapps"

chown -R "${TOMCAT_USER}:${TOMCAT_USER}" "${TOMCAT_HOME}/webapps"
rm -rf "${PEGA_DIR}/install"

#Start tomcat
echo "Restarting tomcat, check logs in ${TOMCAT_HOME}/logs for status"
systemctl restart tomcat