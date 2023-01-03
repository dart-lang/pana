#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd ${SCRIPT_DIR}/../.. && pwd )"
LICENSES_DIR="${PROJECT_DIR}/.dart_tool/pana/license-cache"

mkdir -p "${LICENSES_DIR}"
cd "${LICENSES_DIR}"

# Get all package names
get_all_package_names() { curl -s  -H 'Accept-Encoding: gzip' 'https://pub.dev/api/package-names' | gzip -d | jq -r .packages[]; }

# Given a package name, get archive URL for latest version
get_archive_url() { curl -sL "https://pub.dev/api/packages/$1" | jq -r .latest.archive_url; }

# Given a package name, get LICENSE file from latest version
get_license() { curl -sL $(get_archive_url "$1") | tar -xzO --ignore-case LICENSE 2> /dev/null; }

# Given a package name, download license to LICENSE-<package>.txt
download_license() { get_license "$1" > "LICENSE-$1.txt"; }

export -f get_all_package_names
export -f get_archive_url
export -f get_license
export -f download_license

get_all_package_names | parallel -j 20 download_license
