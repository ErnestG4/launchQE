# launchQE
A script that deploys Quay Enterprise as a single container, along with MySQL and Redis, and generates TLS certs.This was written for debugging. Extra setup is required, especially for production systems. 

# USAGE

Simply run `sudo ./launchQE.sh {version}` where version is in the format `vX.X.X`.

This script launches MySQL 5.7 and Redis:latest, generates certificates for QE, docker, and the builder, and launches the Quay Enterprise container of your choice. 

Copy the files `ssl.cert` and `ssl.key` to a location accessible to the browser used to access the Quay superuser panel, and add them under the "TLS" section of the superuser panel. 

This script will soon include launching a builder, but the builder will crash loop until TLS is properly provided to Quay Enterprise as the builder will be auto-populated with TLS credentials but Quay Enterprise will not.

Please report any issues to: will.garrison@coreos.com

# NOTE: This script requires access to the images on Quay.io and the resulting instance will require a valid Quay Enterprise license.
