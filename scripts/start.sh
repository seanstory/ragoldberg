#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR=`realpath "${SCRIPT_DIR}/../"`
ROOT_DIR="${ROOT_DIR}/"
source "${SCRIPT_DIR}/functions.sh"
export $(cat "${ROOT_DIR}/.env" | xargs)


function start_start_local() {
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

function start_stack(){
  LOCAL_STACK_DIR="${ROOT_DIR}local-stack"
  ES_PID_FILE="${LOCAL_STACK_DIR}/elasticsearch.pid"

  if test -e $ES_PID_FILE; then
    yellow_echo_date "Elasticsearch seems to already be running"
  else
    cd ${LOCAL_STACK_DIR}/elasticsearch-*
    green_echo_date "Starting Elasticsearch..."
    bin/elasticsearch &> "../elasticsearch.log" & ELASTICSEARCH_PID=$!
    green_echo_date "Elasticsearch started with PID: ${ELASTICSEARCH_PID}"
    echo $ELASTICSEARCH_PID > "../elasticsearch.pid"
    cd -
    green_echo_date "Waiting for Elasticsearch to be ready..."
    sleep 15 # TODO make this better
  fi
  curl -XGET --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} "${ES_LOCAL_URL}"
  green_echo_date "Elasticsearch is ready"

  KIBANA_PID_FILE="${LOCAL_STACK_DIR}/kibana.pid"
  if test -e $KIBANA_PID_FILE; then
    yellow_echo_date "Kibana seems to already be running"
  else
    cd ${LOCAL_STACK_DIR}/kibana-*
    green_echo_date "Starting Kibana"
    bin/kibana &> "../kibana.log" & KIBANA_PID=$!
    green_echo_date "Kibana started with PID: ${KIBANA_PID}"
    echo $KIBANA_PID > "../kibana.pid"
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
  set +e
  OLLAMA_VERSION=`ollama -v`
  OLLAMA_RUNNING=$?
  echo $OLLAMA_VERSION | grep "could not connect to a running Ollama instance"
  OLLAMA_NOT_CONNECTED=$?
  set -e
  if [ ${OLLAMA_NOT_CONNECTED} -ne "0" ] && [ ${OLLAMA_RUNNING} -eq "0" ]; then
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

function start_crawler() {
    CRAWLER_DIR="${ROOT_DIR}crawler"

    if test -e $CRAWLER_DIR; then
      if test -e $CRAWLER_DIR/crawler_log.pid; then
        green_echo_date "Crawler already running"
      else
        green_echo_date "Running crawler"
        docker run -i -d \
          --name crawler \
          docker.elastic.co/integrations/crawler:0.2.0
        docker logs -f crawler &> "${CRAWLER_DIR}/crawler.log" & DOCKER_LOGS_PID=$!
        echo ${DOCKER_LOGS_PID} > "${CRAWLER_DIR}/crawler_log.pid"
        docker cp "${ROOT_DIR}config/shared/crawler-es.yml" crawler:app/config/elasticsearch.yml
      fi
    else
      red_echo_date "Crawler was not properly installed. Run 'make install' first"
    fi
}

function run_streamlit_app() {
  STREAMLIT_DIR="${ROOT_DIR}streamlit"
  mkdir -p $STREAMLIT_DIR
  .venv/bin/streamlit run app.py &> "${STREAMLIT_DIR}/serve.log" & STREAMLIT_SERVE_PID=$!
  echo ${STREAMLIT_SERVE_PID} > "$STREAMLIT_DIR/app.pid"
  green_echo_date "RAGolberg is running!"
  sleep 2
  head -n 5 ${STREAMLIT_DIR}/serve.log
}

start_stack
start_crawler
start_ollama
run_streamlit_app
