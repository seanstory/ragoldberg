#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR=`realpath "${SCRIPT_DIR}/../"`
ROOT_DIR="${ROOT_DIR}/"
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

function install_stack_with_start_local(){
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

function install_stack() {
  LOCAL_STACK_DIR="${ROOT_DIR}local-stack"
  if test -e $LOCAL_STACK_DIR/elasticsearch-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}; then
    yellow_echo_date "Elasticsearch is already installed"
  else
    mkdir -p $LOCAL_STACK_DIR
    cd $LOCAL_STACK_DIR
    green_echo_date "Installing Elasticsearch..."
    if test -e "elasticsearch-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}.tar.gz"; then
      green_echo_date "tarball already downloaded, skipping download"
      rm -rf "elasticsearch-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}"
    else
      curl -O "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}.tar.gz"
    fi
    tar -xzf elasticsearch-*.tar.gz
    cd elasticsearch-*
    cp "${ROOT_DIR}config/stack/elasticsearch.yml" config/elasticsearch.yml
    green_echo_date "Starting Elasticsearch..."
    bin/elasticsearch &> "../elasticsearch.log" & ELASTICSEARCH_PID=$!
    green_echo_date "Elasticsearch started with PID: ${ELASTICSEARCH_PID}"
    echo $ELASTICSEARCH_PID > "../elasticsearch.pid"
    green_echo_date "Waiting for Elasticsearch to be ready..."
    sleep 20 # TODO make this better
    green_echo_date "Setting credentials"
    bin/elasticsearch-keystore create<<EOF
N
EOF
    bin/elasticsearch-setup-passwords interactive <<EOF
y
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
${ES_LOCAL_PASSWORD}
EOF
    cd "${ROOT_DIR}"
    curl -XGET --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} "${ES_LOCAL_URL}"
    green_echo_date "Elasticsearch is ready"
  fi

  if test -e $LOCAL_STACK_DIR/kibana-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}; then
    yellow_echo_date "Kibana is already installed"
  else
    mkdir -p $LOCAL_STACK_DIR
    cd $LOCAL_STACK_DIR
    green_echo_date "Installing Kibana..."
    if test -e "kibana-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}.tar.gz"; then
      green_echo_date "tarball already downloaded, skipping download"
      rm -rf "kibana-${ELASTIC_VERSION}"
    else
      curl -O "https://artifacts.elastic.co/downloads/kibana/kibana-${ELASTIC_VERSION}-${PLATFORM_FLAVOR}.tar.gz"
    fi
    tar -xzf kibana-*.tar.gz
    cd kibana-*
    cp "${ROOT_DIR}config/stack/kibana.yml" config/kibana.yml
    green_echo_date "Starting Kibana"
    bin/kibana &> "../kibana.log" & KIBANA_PID=$!
    green_echo_date "Kibana started with PID: ${KIBANA_PID}"
    echo $KIBANA_PID > "../kibana.pid"
    cd "${ROOT_DIR}"
  fi
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

  green_echo_date "creating github connector pipeline"
  curl -XPUT -u elastic:${ES_LOCAL_PASSWORD} \
    -H "Content-Type: application/json" \
    "${ES_LOCAL_URL}/_ingest/pipeline/github-connector-pipeline" \
    -d "@${ROOT_DIR}/resources/github-connector-pipeline.json"
}

function install_crawler() {
  green_echo_date "fetching crawler image..."
  docker pull docker.elastic.co/integrations/crawler:${CRAWLER_VERSION}
  CRAWLER_DIR="${ROOT_DIR}crawler"
  mkdir -p $CRAWLER_DIR
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
