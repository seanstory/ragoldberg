#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"

function remove_stack() {
  START_LOCAL_DIR="${ROOT_DIR}start-local/"
  NESTED_START_LOCAL_DIR="${START_LOCAL_DIR}elastic-start-local/"
  if test -e ${START_LOCAL_DIR}; then
    green_echo_date "Removing start-local"
    if test -e ${NESTED_START_LOCAL_DIR}; then
      yes | ./${START_LOCAL_DIR}elastic-start-local/uninstall.sh
    fi
    rm -rf START_LOCAL_DIR
  fi
}

function remove_ollama() {
  OLLAMA_DIR="${ROOT_DIR}ollama"
  if test -e $OLLAMA_DIR; then
    set +e
    green_echo_date "Stopping ollama server"
    OLLAMA_PID=`cat "$OLLAMA_DIR/serve.pid"`
    kill $OLLAMA_PID
    set -e
    green_echo_date "Removing ollama"
    rm -rf $OLLAMA_DIR
  fi
}

remove_stack
remove_ollama

