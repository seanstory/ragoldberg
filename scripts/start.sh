#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"
export $(cat "${ROOT_DIR}/.env" | xargs)


function start_stack() {
  START_LOCAL_DIR="${ROOT_DIR}start-local"
  NESTED_START_LOCAL_DIR="${START_LOCAL_DIR}/elastic-start-local/"
  echo "path is: ${NESTED_START_LOCAL_DIR}"
  if test -e $NESTED_START_LOCAL_DIR; then
    green_echo_date "Starting Elasticsearch/Kibana"
    yes | ./${START_LOCAL_DIR}/elastic-start-local/start.sh
    export $(cat "${NESTED_START_LOCAL_DIR}.env" | xargs)
  else
    red_echo_date "Elasticsearch/Kibana are not installed"
    exit 1
  fi
}

function start_ollama(){
  if  ollama --help > /dev/null 2>&1; then
    green_echo_date "Starting ollama"
  else
    red_echo_date "ollama not found. Did brew fail to install it?"
    exit 1
  fi
  OLLAMA_DIR="${ROOT_DIR}ollama"
  mkdir -p $OLLAMA_DIR
  ollama -v | grep "could not connect to a running Ollama instance"
  OLLAMA_RUNNING=$?
  if [ ${OLLAMA_RUNNING} -ne "0" ]; then
    yellow_echo_date "ollama already running"
  else
    ollama serve &> "${OLLAMA_DIR}/serve.log" & OLLAMA_SERVE_PID=$!
    green_echo_date "Ollama server started with PID: ${OLLAMA_SERVE_PID}"
    echo $OLLAMA_SERVE_PID > "${OLLAMA_DIR}/serve.pid"
    green_echo_date "Waiting for ollama server to be ready..."
    until ollama -v > /dev/null 2>&1; do
      sleep 1
    done
  fi
  green_echo_date "Installing LLM (${MODEL})"
  ollama pull $MODEL
}

function run_streamlit_app() {
  STREAMLIT_DIR="${ROOT_DIR}streamlit"
  mkdir -p $STREAMLIT_DIR
  .venv/bin/streamlit run app.py &> "${STREAMLIT_DIR}/serve.log" & STREAMLIT_SERVE_PID=$!
  echo ${STREAMLIT_SERVE_PID} > "$STREAMLIT_DIR/app.pid"
  green_echo_date "RAGolberg is running! Open http://localhost:8502"
}

start_stack
start_ollama
run_streamlit_app