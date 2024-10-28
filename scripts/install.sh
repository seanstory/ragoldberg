#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"
source "${ROOT_DIR}.env"

function install_brew(){
  if  brew --help > /dev/null 2>&1; then
    green_echo_date "Installing brew-installable deps"
    brew bundle
  else
    red_echo_date "brew not found. You must install homebrew"
    exit 1
  fi
}

function check_docker(){
  if docker info > /dev/null 2>&1; then
      green_echo_date "Docker is running"
  else
      red_echo_date "Docker is not running"
      exit 1
  fi
}

function install_stack(){
  # start local gets its own dir, because if it errors, it doesn't write error logs to its own dir
  START_LOCAL_DIR="${ROOT_DIR}start-local"
  if test -e $START_LOCAL_DIR; then
    yellow_echo_date "Elasticsearch/Kibana already installed"
  else
    mkdir -p $START_LOCAL_DIR
    cd $START_LOCAL_DIR
    green_echo_date "Installing Elasticsearch and Kibana"
    curl -fsSL https://elastic.co/start-local | sh
    cd -
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
  if test -e "${OLLAMA_DIR}/serve.pid"; then
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

install_brew
check_docker
install_stack
start_ollama
