# Deploying Pega on GCP using Compute Engine and Cloud SQL

## Overview

This repository contains the accompanying code for the
[Deploying Pega on GCP using Compute Engine and Cloud SQL](link_address)
tutorial.

The scripts in this repository are used by the tutorial to install, configure
and run Pega 7.4 on Compute Engine. The scripts were designed to run on RedHat Enterprise Linux 7 (RHEL). Please see the turorial for more details.

## Important directories and files

### Directories

*   `pega/` - Contains the scripts for installing Pega on Cloud SQL and configuring the Compute Engine
    application servers.
*   `systemd/` - Contains service definition for Cloud SQL Proxy and Tomcat
*   `tomcat/` - Contains xml config files environment variables for Tomcat required by Pega.

### Files

*   `pega/db-startup.sh` - This script is used to bootstrap a Compute Engine
    instance which installs the Pega Rulebase on Cloud SQL.
*   `pega/app-startup.sh` - This script is used to bootstrap the Pega application
    on a Compute Engine instance.    
*   `pega/env.sh` - Initializes a set of environment variables from instance
    metadata.
*   `pega/installpega.sh` - Installs the Pega Rulebase on Cloud SQL by executing installation scripts from a
    Compute Engine instance.
*   `pega/setupapp.sh` - Installs the Pega application server on a Compute Engine instance.

# Database installation

`pega/db-startup.sh` is intended to be invoked as a Compute Engine startup script. When it is invoked, it downloads the remaining scripts 
and Pega installation media and then invokes `pega/installpega.sh.`
`pega/installpega.sh` imports required environment variables from
`pega/env.sh`, runs system updates, installs required components and executes the Pega rulebase installation scripts found in the Pega installation media.

# Application server installation

`pega/app-startup.sh` is intended to be invoked as a Compute Engine startup script. When it is invoked, it downloads the remaining scripts
and Pega installation media and then invokes `pega/setupapp.sh`.
`pega/setupapp.sh` imports required environment variables from `pega/env.sh`,
 runs system updates, installs required components, deploys the service definitions in `systemd/`,
installs the Tomcat configurations from the `tomcat/` folder and deploys the Pega web application in Tomcat
