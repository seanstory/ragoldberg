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
    set +e
    if test -e ${NESTED_START_LOCAL_DIR}; then
      yes | ./${START_LOCAL_DIR}elastic-start-local/uninstall.sh
    fi
    set -e
    rm -rf $START_LOCAL_DIR
  fi
}

function remove_ollama() {
  OLLAMA_DIR="${ROOT_DIR}ollama"
  if test -e $OLLAMA_DIR; then
    green_echo_date "Removing ollama"
    rm -rf $OLLAMA_DIR
  fi
}

function clean_python_env() {
  green_echo_date "Removing python virtual environment"
  rm -rf .venv
}

remove_stack
remove_ollama
clean_python_env

