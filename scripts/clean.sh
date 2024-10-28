#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"

START_LOCAL_DIR="${ROOT_DIR}start-local/"
NESTED_START_LOCAL_DIR="${START_LOCAL_DIR}elastic-start-local/"

green_echo_date "Removing start-local"
if test -e ${START_LOCAL_DIR}; then
  if test -e ${NESTED_START_LOCAL_DIR}; then
    yes | ./${START_LOCAL_DIR}elastic-start-local/uninstall.sh
  fi
fi
rm -rf ${ROOT_DIR}start-local
