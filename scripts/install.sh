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
    cd -
  fi
  export $(cat "${START_LOCAL_DIR}/elastic-start-local/.env" | xargs)
  set -x
  curl -XGET --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} "${ES_LOCAL_URL}"
}

function install_elser() {
  green_echo_date "installing ELSER..."
  MAX_RETRIES=3
  n=0
  until [ "$n" -ge $MAX_RETRIES ]
  do
    set -x
    set +e
    curl -XPUT --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} \
      -H "Content-Type: application/json" \
      "${ES_LOCAL_URL}/_inference/sparse_embedding/elser-endpoint" \
       -d "@${ROOT_DIR}/resources/elser_endpoint.json" && green_echo_date "ELSER installed" && break
    set -e
    set +x
    n=$((n+1))
    sleep 5
  done
  if [[ $n -eq $MAX_RETRIES ]]; then
    red_echo_date "Failed to install ELSER, even after ${MAX_RETRIES} retries"
    exit 1
  fi
  set +x
}

function setup_es_resources() {
  green_echo_date "Creating an index template to match search-rag-*"
  curl -XPUT --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} \
    -H "Content-Type: application/json" \
    "${ES_LOCAL_URL}/_index_template/ragoldberg-v1" \
    -d "@${ROOT_DIR}/resources/search-rag-index-template.json"
  green_echo_date "index template installed"

  green_echo_date "creating empty index to instantiate alias"
  curl -XPUT -u elastic:${ES_LOCAL_PASSWORD} \
       "${ES_LOCAL_URL}/search-rag-test"

  green_echo_date "creating crawler pipeline"
  curl -XPUT -u elastic:${ES_LOCAL_PASSWORD} \
    -H "Content-Type: application/json" \
    "${ES_LOCAL_URL}/_ingest/pipeline/crawler-pipeline" \
    -d "@${ROOT_DIR}/resources/crawler-pipeline.json"


}

function install_crawler() {
  green_echo_date "fetching crawler image..."
  docker pull docker.elastic.co/integrations/crawler:${CRAWLER_VERSION}
  CRAWLER_DIR="${ROOT_DIR}crawler"
  mkdir -p $CRAWLER_DIR
  CRAWLER_ES_CONFIG="${CRAWLER_DIR}/elasticsearch.yml"
  rm -f $CRAWLER_ES_CONFIG
  echo "
elasticsearch:
  host: http://host.docker.internal
  port: ${ES_LOCAL_PORT}
  username: elastic
  password: ${ES_LOCAL_PASSWORD}
  pipeline: crawler-pipeline
  bulk_api:
    max_items: 1
" > $CRAWLER_ES_CONFIG
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
setup_es_resources
install_crawler
install_streamlit_app
green_echo_date "Finished installing"
