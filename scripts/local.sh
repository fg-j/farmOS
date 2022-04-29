#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOTDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly DEVDIR="${ROOTDIR}/.dev"

function main() {

  directory::prepare
  server::start
}

function directory::prepare() {
  rm -rf "${DEVDIR}"
  mkdir -p "${DEVDIR}"

  cp "${ROOTDIR}"/docker/docker-compose.development.yml "${DEVDIR}"/docker-compose.yml

  pushd "${DEVDIR}"
  docker-compose up
}

main "${@:-}"
