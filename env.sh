#!/bin/bash

DOCKER_HUB_USER=
DOCKER_HUB_PASS=
DOCKER_HUB_EMAIL=

DOCKER_SECRET_NAME=docker-io-secret

export DOCKER_HUB_USER DOCKER_HUB_PASS DOCKER_HUB_EMAIL DOCKER_SECRET_NAME

INTEGRATION_IMAGE_NAME=integration-service:altyn
FRONTEND_IMAGE_NAME=customerui:altyn
BACKEND_IMAGE_NAME=core:oracle_scripts
FRONTEND_SVC=customerui
BACKEND_SVC=core
INTEGRATION_SVC=integration-service

export INTEGRATION_IMAGE_NAME FRONTEND_IMAGE_NAME BACKEND_IMAGE_NAME FRONTEND_SVC BACKEND_SVC INTEGRATION_SVC

DB_HOST=10.1.1.1
DB_PORT=1521
DB_SID=oradb
DB_USER=oracle
DB_PASS=oracle

export DB_HOST DB_PORT DB_SID DB_USER DB_PASS

FILESERVER_IP=
FILESERVER_PORT=8080

export FILESERVER_IP FILESERVER_PORT

