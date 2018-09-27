#!/bin/bash
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

# JVM Heap Size, as recommended by Pega documentation for this scale of deployment
CATALINA_OPTS="-Xms4G -Xmx4G"

# Garbage Collection log settings
CATALINA_OPTS="$CATALINA_OPTS
		-XX:+PrintGCDetails
		-XX:+PrintGCDateStamps
		-XX:+PrintGCTimeStamps
		-XX:+HeapDumpOnOutOfMemoryError
		-Xloggc:$CATALINA_HOME/logs/gc.%t.log
		-XX:-UseGCLogFileRotation
		-XX:NumberOfGCLogFiles=10
		-XX:GCLogFileSize=100M"

# Garbage collector Settings
CATALINA_OPTS="$CATALINA_OPTS
		-XX:+UseG1GC
		-XX:ReservedCodeCacheSize=512m
		-XX:+UseCodeCacheFlushing
		-XX:+DisableExplicitGC"

# JMX Access Settings
CATALINA_OPTS="$CATALINA_OPTS
		-Dcom.sun.management.jmxremote
		-Dcom.sun.management.jmxremote.ssl=false
		-Dcom.sun.management.jmxremote.authenticate=false
		-Dcom.sun.management.jmxremote.port=9012"

# Pega Specific settings
CATALINA_OPTS="$CATALINA_OPTS
		-Dindex.directory=<index_directory>"