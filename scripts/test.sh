#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOTDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly TESTINGDIR="${ROOTDIR}/.testing"

function main() {
  local db url processes
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --database|-d)
        db="${2}"
        shift 2
        ;;

      --database-url|-u)
        url="${2}"
        shift 2
        ;;

      --processes|-p)
        processes="${2}"
        shift 2
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        echo "unknown argument \"${1}\""
        exit 1
    esac
  done

  if [[ -z "${db:-}" ]]; then
    usage
    echo
    echo "--database is required"
    exit 1
  fi

  if [[ -z "${url:-}" ]]; then
    usage
    echo
    echo "--url is required"
    exit 1
  fi

  if [[ -z "${processes:-}" ]]; then
    usage
    echo
    echo "--processes is required"
    exit 1
  fi

  directory::prepare
  tests::run "${db}" "${url}" "${processes}"
}

function usage() {
  cat <<-USAGE
test.sh --database <database> --database-url <url> --processes <number> [OPTIONS]

Packages the buildpack into a buildpackage .cnb file.

OPTIONS
  --help                    -h              prints the command usage
  --database <database>     -d <database>   specifies the database to test against (pgsql | mariadb | sqlite)
  --database-url <url>      -u <url>        specifies the URL to use to connect to the database
  --processes <number>      -p <number>     specifies the number of concurrent testing processes to run
USAGE
}

function directory::prepare() {
  rm -rf "${TESTINGDIR}"
  mkdir -p "${TESTINGDIR}"

  cp "${ROOTDIR}"/docker/docker-compose.testing.* "${TESTINGDIR}"

}

function tests::run() {
  local db url processes
  db="${1}"
  url="${2}"
  processes="${3}"

  pushd "${TESTINGDIR}"

  echo "Running ${db} tests"

  docker-compose -f docker-compose.testing.common.yml -f "docker-compose.testing.${db}.yml" config > docker-compose.yml
  docker-compose up -d
  # The www-container-fs-ready file is only created once we expect the containers to be online
  echo -n "Waiting for containers to be ready..."
  until [ -f ./www/www-container-fs-ready ]; do
    sleep 5
    echo -n "."
  done
  echo
  echo "Containers are ready."

  docker-compose exec -u www-data -T www paratest --verbose=1 --processes="${processes}" /opt/drupal/web/profiles/farm
  docker-compose exec -u www-data -T www drush site-install --db-url="${url}" farm farm.modules='all'

  docker-compose rm -f
  popd
}

main "${@:-}"
