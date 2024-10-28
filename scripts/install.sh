#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"


if docker info > /dev/null 2>&1; then
    green_echo_date "Docker is running"
else
    red_echo_date "Docker is not running"
    exit 1
fi

# start local gets its own dir, because if it errors, it doesn't write error logs to its own dir
START_LOCAL_DIR="${ROOT_DIR}start-local"
if test -e $START_LOCAL_DIR; then
  yello_echo_date "Elasticsearch/Kibana already installed"
else
  mkdir -p $START_LOCAL_DIR
  cd $START_LOCAL_DIR
  green_echo_date "Installing Elasticsearch and Kibana"
  curl -fsSL https://elastic.co/start-local | sh
  cd -
fi

