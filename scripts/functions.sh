#!/bin/bash

# Do not color output in environments that do not have the TERM set (no TTY in docker, etc)
if [ "${TERM:-dumb}" == "dumb" ]; then
  echo "Warning: No TERM defined, output coloring will be disabled!"
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
else
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  RESET=$(tput sgr0)
fi

#---------------------------------------------------------------------------------------------------
function yellow_echo() {
  echo "${YELLOW}${*}${RESET}"
}

function yellow_echo_date() {
  yellow_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}

function red_echo()    {
  echo "${RED}${*}${RESET}"
}

function red_echo_date() {
  red_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}

function green_echo()  {
  echo "${GREEN}${*}${RESET}"
}

function green_echo_date() {
  green_echo "[$(date +"%Y-%m-%d %H:%M:%S")] ${*}"
}
