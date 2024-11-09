#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
ROOT_DIR=`realpath "${SCRIPT_DIR}/../"`
ROOT_DIR="${ROOT_DIR}/"
source "${SCRIPT_DIR}/functions.sh"
export $(cat "${ROOT_DIR}/.env" | xargs)

function do_crawls() {
  CRAWLER_DIR="${ROOT_DIR}crawler"
  if test -e $CRAWLER_DIR; then
    green_echo_date "Looping over all crawl configs"
    CRAWLS_DIR="${ROOT_DIR}config/crawls"
    for crawl_yml_file in `ls ${CRAWLS_DIR} | grep '.*yml$'`; do
      green_echo_date "Kicking off ${crawl_yml_file}"
      docker cp "${CRAWLS_DIR}/${crawl_yml_file}" "crawler:app/config/${crawl_yml_file}"
      docker exec -it crawler bin/crawler crawl "/app/config/${crawl_yml_file}" --es-config /app/config/elasticsearch.yml
    done
  else
    red_echo_date "Crawler is not installed correctly. Run 'make install' and 'make start'"
  fi
}

function do_reindex_in_place() {
  green_echo_date "Kicking off Elastic docs data reindex:"
  curl -XPOST --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} \
    -H "Content-Type: application/json" \
    "${ES_LOCAL_URL}/_reindex?wait_for_completion=false&requests_per_second=1" \
    -d "@${ROOT_DIR}/resources/elastic-docs-reindex.json"
  echo

  green_echo_date "Kicking off Search Labs blogs data reindex:"

  curl -XPOST --fail-with-body -u elastic:${ES_LOCAL_PASSWORD} \
    -H "Content-Type: application/json" \
    "${ES_LOCAL_URL}/_reindex?wait_for_completion=false&requests_per_second=1" \
    -d "@${ROOT_DIR}/resources/search-labs-blogs-reindex.json"
  echo
}

do_crawls
do_reindex_in_place
green_echo_date "Finished ingestion!"
