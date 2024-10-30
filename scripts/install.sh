#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR="${SCRIPT_DIR}/../"
source "${SCRIPT_DIR}/functions.sh"
export $(cat "${ROOT_DIR}/.env" | xargs)

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
    export $(cat "elastic-start-local/.env" | xargs)
    cd -
  fi
}

function install_elser() {
  green_echo_date "installing ELSER..."
  curl -XPUT -u elastic:${ES_LOCAL_PASSWORD} "${ES_LOCAL_URL}/_inference/sparse_embedding/elser-endpoint" \
    -d "@${ROOT_DIR}/resources/elser_endpoint.json"
  green_echo_date "ELSER installed"
}



function install_streamlit_app() {
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip
  .venv/bin/pip install --upgrade setuptools
  .venv/bin/pip install -r requirements.txt
}

install_brew
check_docker
install_stack
install_elser
install_streamlit_app
