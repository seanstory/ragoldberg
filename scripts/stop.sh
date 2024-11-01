#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR=`realpath "${SCRIPT_DIR}/../"`
ROOT_DIR="${ROOT_DIR}/"
source "${SCRIPT_DIR}/functions.sh"

function stop_start_local() {
  START_LOCAL_DIR="${ROOT_DIR}start-local/"
  NESTED_START_LOCAL_DIR="${START_LOCAL_DIR}elastic-start-local/"
  if test -e ${START_LOCAL_DIR}; then
    if test -e ${NESTED_START_LOCAL_DIR}; then
      green_echo_date "Stopping start-local"
      yes | ./${START_LOCAL_DIR}elastic-start-local/stop.sh
    fi
  fi
}

function stop_stack() {
  LOCAL_STACK_DIR="${ROOT_DIR}local-stack"
  if test -e ${LOCAL_STACK_DIR}; then
    green_echo_date "Stopping the local stack"
    ES_PID_FILE="${LOCAL_STACK_DIR}/elasticsearch.pid"
    KIBANA_PID_FILE="${LOCAL_STACK_DIR}/kibana.pid"
    set +e
    KIBANA_PID=`cat $KIBANA_PID_FILE` && kill ${KIBANA_PID}
    rm $KIBANA_PID_FILE
    ELASTICSEARCH_PID=`cat $ES_PID_FILE` && kill ${ELASTICSEARCH_PID}
    rm $ES_PID_FILE
    set -e
  else
    yellow_echo_date "Local stack doesn't seem to be running"
  fi
}

function stop_crawler() {
    CRAWLER_DIR="${ROOT_DIR}crawler"
    if test -e $CRAWLER_DIR; then
      green_echo_date "Stopping crawler"
      set +e
      docker stop crawler
      docker rm crawler
      CRAWLER_LOG_PID=`cat "${CRAWLER_DIR}/crawler_log.pid"`
      kill $CRAWLER_LOG_PID
      set -e
    else
      yellow_echo_date "crawler doesn't seem to be running"
    fi
}

function stop_ollama() {
  OLLAMA_DIR="${ROOT_DIR}ollama"
  if test -e $OLLAMA_DIR; then
    set +e
    green_echo_date "Stopping ollama server"
    OLLAMA_PID=`cat "$OLLAMA_DIR/serve.pid"`
    kill $OLLAMA_PID
    set -e
  else
    yellow_echo_date "Ollama doesn't seem to be running"
  fi
}

function stop_streamlit_app() {
  STREAMLIT_DIR="${ROOT_DIR}streamlit"
  if test -e $STREAMLIT_DIR; then
    set +e
    green_echo_date "Stopping streamlit app"
    STREAMLIT_PID=`cat "${STREAMLIT_DIR}/app.pid"`
    kill $STREAMLIT_PID
    set -e
  else
    yellow_echo_date "streamlit app doesn't seem to be running"
  fi
}

stop_crawler
stop_stack
stop_ollama
stop_streamlit_app
