#!/bin/bash

set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR=`realpath "${SCRIPT_DIR}/../"`
ROOT_DIR="${ROOT_DIR}/"
source "${SCRIPT_DIR}/functions.sh"

function remove_start_local_stack() {
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

function remove_stack() {
  LOCAL_STACK_DIR="${ROOT_DIR}local-stack"
  if test -e $LOCAL_STACK_DIR; then
    green_echo_date "Removing local stack"
    rm -rf $LOCAL_STACK_DIR
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

function clean_crawler() {
  CRAWLER_DIR="${ROOT_DIR}crawler"
  set +e
  docker rm crawler
  set -e
  rm -rf $CRAWLER_DIR
}

function clean_streamlit() {
  rm -rf "${ROOT_DIR}streamlit"
}

clean_crawler
remove_stack
remove_ollama
clean_python_env
clean_streamlit
green_echo_date "Finished cleaning up"

